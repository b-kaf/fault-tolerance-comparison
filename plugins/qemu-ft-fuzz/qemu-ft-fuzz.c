#include <qemu-plugin.h>

#include <errno.h>
#include <inttypes.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

QEMU_PLUGIN_EXPORT int qemu_plugin_version = QEMU_PLUGIN_VERSION;

#define MAX_SYMBOLS 128
#define MAX_FUZZ_SYMBOLS 32
#define MAX_REGS 16

typedef enum {
    TECH_TMR,
    TECH_CHECKPOINT,
    TECH_RECOVERY_BLOCK,
    TECH_CONTROL_FLOW,
    TECH_UNKNOWN,
} Technique;

typedef enum {
    MODE_NONE,
    MODE_ABI_NONE,
    MODE_ABI_MIXED,
    MODE_RAM_SYMBOL_BITFLIP,
    MODE_REG_BITFLIP_WINDOW,
} FaultMode;

typedef struct {
    char name[96];
    uint64_t addr;
    uint64_t size;
} NamedAddress;

typedef struct {
    char name[16];
    struct qemu_plugin_register *handle;
} RegisterHandle;

typedef struct {
    char technique[32];
    char language[16];
    char campaign[64];
    char csv_path[512];
    char done_path[512];
    uint64_t seed;
    uint32_t iterations;
    uint64_t start_pc;
    uint64_t end_pc;
    uint64_t text_start;
    uint64_t text_end;
    NamedAddress symbols[MAX_SYMBOLS];
    size_t symbol_count;
    NamedAddress fuzz_symbols[MAX_FUZZ_SYMBOLS];
    size_t fuzz_symbol_count;
} Config;

typedef struct {
    bool injected;
    char fault_mode[32];
    char target_kind[32];
    char target_name[96];
    uint64_t inject_pc;
    uint64_t inject_offset;
    uint64_t target_addr;
    uint32_t bit;
    uint32_t before;
    uint32_t after;
    uint32_t fault_target;
    uint32_t fault_value;
} FaultRecord;

typedef struct {
    qemu_plugin_id_t id;
    Config config;
    Technique technique;
    FaultMode mode;
    FILE *csv;
    bool done;
    bool active_window;
    uint32_t rows_written;
    uint64_t rng_state;
    uint64_t window_insns_seen;
    uint64_t reg_inject_after;
    size_t selected_reg;
    RegisterHandle regs[MAX_REGS];
    size_t reg_count;
    FaultRecord fault;
} PluginState;

static PluginState g;

static void plugin_log(const char *message)
{
    qemu_plugin_outs(message);
}

static void plugin_log2(const char *prefix, const char *value)
{
    char buf[1024];
    snprintf(buf, sizeof(buf), "%s%s\n", prefix, value);
    qemu_plugin_outs(buf);
}

static char *trim(char *value)
{
    while (*value == ' ' || *value == '\t' || *value == '\n' || *value == '\r') {
        value++;
    }
    size_t len = strlen(value);
    while (len > 0) {
        char c = value[len - 1];
        if (c != ' ' && c != '\t' && c != '\n' && c != '\r') {
            break;
        }
        value[--len] = '\0';
    }
    return value;
}

static bool parse_u64(const char *value, uint64_t *out)
{
    errno = 0;
    char *end = NULL;
    uint64_t parsed = strtoull(value, &end, 0);
    if (errno != 0 || end == value || *trim(end) != '\0') {
        return false;
    }
    *out = parsed;
    return true;
}

static void copy_str(char *dest, size_t dest_size, const char *src)
{
    if (dest_size == 0) {
        return;
    }
    snprintf(dest, dest_size, "%s", src);
}

static NamedAddress *append_named_address(NamedAddress *items, size_t *count,
                                          size_t max_count, const char *name)
{
    if (*count >= max_count) {
        return NULL;
    }
    NamedAddress *item = &items[*count];
    memset(item, 0, sizeof(*item));
    copy_str(item->name, sizeof(item->name), name);
    *count += 1;
    return item;
}

static NamedAddress *find_symbol(const char *name)
{
    for (size_t i = 0; i < g.config.symbol_count; i++) {
        if (strcmp(g.config.symbols[i].name, name) == 0) {
            return &g.config.symbols[i];
        }
    }
    return NULL;
}

static bool read_u32_addr(uint64_t addr, uint32_t *out)
{
    GByteArray *bytes = g_byte_array_sized_new(sizeof(uint32_t));
    enum qemu_plugin_hwaddr_operation_result result =
        qemu_plugin_read_memory_hwaddr(addr, bytes, sizeof(uint32_t));
    if (result != QEMU_PLUGIN_HWADDR_OPERATION_OK || bytes->len < sizeof(uint32_t)) {
        g_byte_array_unref(bytes);
        return false;
    }

    const uint8_t *data = bytes->data;
    *out = ((uint32_t)data[0])
        | ((uint32_t)data[1] << 8)
        | ((uint32_t)data[2] << 16)
        | ((uint32_t)data[3] << 24);
    g_byte_array_unref(bytes);
    return true;
}

static bool write_u32_addr(uint64_t addr, uint32_t value)
{
    uint8_t raw[sizeof(uint32_t)] = {
        (uint8_t)(value & 0xffu),
        (uint8_t)((value >> 8) & 0xffu),
        (uint8_t)((value >> 16) & 0xffu),
        (uint8_t)((value >> 24) & 0xffu),
    };
    GByteArray *bytes = g_byte_array_sized_new(sizeof(raw));
    g_byte_array_append(bytes, raw, sizeof(raw));
    enum qemu_plugin_hwaddr_operation_result result =
        qemu_plugin_write_memory_hwaddr(addr, bytes);
    g_byte_array_unref(bytes);
    return result == QEMU_PLUGIN_HWADDR_OPERATION_OK;
}

static bool read_symbol_u32(const char *name, uint32_t *out)
{
    NamedAddress *symbol = find_symbol(name);
    if (symbol == NULL) {
        *out = 0;
        return false;
    }
    return read_u32_addr(symbol->addr, out);
}

static bool write_symbol_u32(const char *name, uint32_t value)
{
    NamedAddress *symbol = find_symbol(name);
    if (symbol == NULL) {
        return false;
    }
    return write_u32_addr(symbol->addr, value);
}

static uint32_t read_symbol_u32_or_zero(const char *name)
{
    uint32_t value = 0;
    (void)read_symbol_u32(name, &value);
    return value;
}

static uint64_t rng_next(void)
{
    uint64_t x = g.rng_state;
    x ^= x >> 12;
    x ^= x << 25;
    x ^= x >> 27;
    g.rng_state = x;
    return x * UINT64_C(2685821657736338717);
}

static uint32_t rng_bounded(uint32_t bound)
{
    if (bound == 0) {
        return 0;
    }
    return (uint32_t)(rng_next() % bound);
}

static Technique parse_technique(const char *value)
{
    if (strcmp(value, "tmr") == 0) {
        return TECH_TMR;
    }
    if (strcmp(value, "checkpoint") == 0) {
        return TECH_CHECKPOINT;
    }
    if (strcmp(value, "recovery-block") == 0) {
        return TECH_RECOVERY_BLOCK;
    }
    if (strcmp(value, "control-flow") == 0) {
        return TECH_CONTROL_FLOW;
    }
    return TECH_UNKNOWN;
}

static FaultMode parse_mode(const char *campaign)
{
    if (strcmp(campaign, "none") == 0) {
        return MODE_NONE;
    }
    if (strcmp(campaign, "abi-none") == 0) {
        return MODE_ABI_NONE;
    }
    if (strcmp(campaign, "abi-mixed") == 0) {
        return MODE_ABI_MIXED;
    }
    if (strcmp(campaign, "ram-symbol-bitflip") == 0) {
        return MODE_RAM_SYMBOL_BITFLIP;
    }
    if (strcmp(campaign, "reg-bitflip-window") == 0) {
        return MODE_REG_BITFLIP_WINDOW;
    }
    return MODE_NONE;
}

static const char *mode_name(FaultMode mode)
{
    switch (mode) {
    case MODE_NONE:
        return "none";
    case MODE_ABI_NONE:
        return "abi";
    case MODE_ABI_MIXED:
        return "abi";
    case MODE_RAM_SYMBOL_BITFLIP:
        return "ram-symbol-bitflip";
    case MODE_REG_BITFLIP_WINDOW:
        return "reg-bitflip-window";
    }
    return "unknown";
}

static void reset_fault_record(void)
{
    memset(&g.fault, 0, sizeof(g.fault));
    copy_str(g.fault.fault_mode, sizeof(g.fault.fault_mode), mode_name(g.mode));
    copy_str(g.fault.target_kind, sizeof(g.fault.target_kind), "none");
}

static void choose_abi_fault(uint32_t iteration, uint32_t expected,
                             uint32_t *target, uint32_t *value)
{
    *target = 0;
    *value = 0;

    if (g.mode == MODE_ABI_NONE) {
        return;
    }

    switch (g.technique) {
    case TECH_TMR:
        switch ((iteration - 1) % 3) {
        case 1:
            *target = 1;
            *value = expected ^ UINT32_C(0xffffffff);
            break;
        case 2:
            *target = 2;
            *value = expected ^ UINT32_C(0x13579bdf);
            break;
        default:
            break;
        }
        break;
    case TECH_CHECKPOINT:
        switch ((iteration - 1) % 6) {
        case 1:
            *target = 10;
            *value = UINT32_C(0xffffffff);
            break;
        case 2:
            *target = 11;
            *value = UINT32_C(0xffffffff);
            break;
        case 3:
            *target = 12;
            *value = UINT32_C(0x10);
            break;
        case 4:
            *target = 14;
            *value = UINT32_C(0x10);
            break;
        case 5:
            *target = 15;
            *value = UINT32_C(0xffffffff);
            break;
        default:
            break;
        }
        break;
    case TECH_RECOVERY_BLOCK:
        switch ((iteration - 1) % 5) {
        case 1:
            *target = 20;
            *value = UINT32_C(0xffffffff);
            break;
        case 2:
            *target = 21;
            *value = UINT32_C(0x10);
            break;
        case 3:
            *target = 22;
            *value = UINT32_C(0xffffffff);
            break;
        case 4:
            *target = 23;
            *value = UINT32_C(0xffffffff);
            break;
        default:
            break;
        }
        break;
    case TECH_CONTROL_FLOW:
        switch ((iteration - 1) % 6) {
        case 1:
            *target = 30;
            *value = 4;
            break;
        case 2:
            *target = 31;
            *value = UINT32_C(0x10);
            break;
        case 3:
            *target = 32;
            break;
        case 4:
            *target = 33;
            break;
        case 5:
            *target = 34;
            break;
        default:
            break;
        }
        break;
    case TECH_UNKNOWN:
        break;
    }
}

static void inject_abi_fault(uint32_t iteration)
{
    uint32_t expected = read_symbol_u32_or_zero("harness_last_expected");
    uint32_t target = 0;
    uint32_t value = 0;
    choose_abi_fault(iteration, expected, &target, &value);

    g.fault.injected = true;
    g.fault.inject_pc = g.config.start_pc;
    g.fault.fault_target = target;
    g.fault.fault_value = value;
    g.fault.before = 0;
    g.fault.after = value;
    copy_str(g.fault.target_kind, sizeof(g.fault.target_kind), "harness-abi");
    copy_str(g.fault.target_name, sizeof(g.fault.target_name), "harness_fault_target");

    (void)write_symbol_u32("harness_fault_value", value);
    (void)write_symbol_u32("harness_fault_target", target);
}

static void inject_ram_symbol_fault(void)
{
    if (g.config.fuzz_symbol_count == 0) {
        copy_str(g.fault.target_kind, sizeof(g.fault.target_kind), "no-fuzz-symbol");
        return;
    }

    uint32_t symbol_index = rng_bounded((uint32_t)g.config.fuzz_symbol_count);
    NamedAddress *symbol = &g.config.fuzz_symbols[symbol_index];
    uint64_t word_count = symbol->size / sizeof(uint32_t);
    if (word_count == 0) {
        word_count = 1;
    }
    uint64_t word_index = rng_next() % word_count;
    uint64_t addr = symbol->addr + word_index * sizeof(uint32_t);
    uint32_t bit = rng_bounded(32);
    uint32_t before = 0;

    if (!read_u32_addr(addr, &before)) {
        copy_str(g.fault.target_kind, sizeof(g.fault.target_kind), "ram-read-failed");
        copy_str(g.fault.target_name, sizeof(g.fault.target_name), symbol->name);
        g.fault.target_addr = addr;
        g.fault.bit = bit;
        return;
    }

    uint32_t after = before ^ (UINT32_C(1) << bit);
    if (!write_u32_addr(addr, after)) {
        copy_str(g.fault.target_kind, sizeof(g.fault.target_kind), "ram-write-failed");
        copy_str(g.fault.target_name, sizeof(g.fault.target_name), symbol->name);
        g.fault.target_addr = addr;
        g.fault.bit = bit;
        g.fault.before = before;
        g.fault.after = after;
        return;
    }

    g.fault.injected = true;
    g.fault.inject_pc = g.config.start_pc;
    g.fault.inject_offset = word_index * sizeof(uint32_t);
    g.fault.target_addr = addr;
    g.fault.bit = bit;
    g.fault.before = before;
    g.fault.after = after;
    copy_str(g.fault.target_kind, sizeof(g.fault.target_kind), "ram-symbol");
    copy_str(g.fault.target_name, sizeof(g.fault.target_name), symbol->name);
}

static bool read_register_u32(size_t index, uint32_t *out, GByteArray **out_bytes)
{
    GByteArray *bytes = g_byte_array_sized_new(sizeof(uint32_t));
    int len = qemu_plugin_read_register(g.regs[index].handle, bytes);
    if (len < (int)sizeof(uint32_t) || bytes->len < sizeof(uint32_t)) {
        g_byte_array_unref(bytes);
        return false;
    }

    const uint8_t *data = bytes->data;
    *out = ((uint32_t)data[0])
        | ((uint32_t)data[1] << 8)
        | ((uint32_t)data[2] << 16)
        | ((uint32_t)data[3] << 24);
    *out_bytes = bytes;
    return true;
}

static bool write_register_u32(size_t index, GByteArray *bytes, uint32_t value)
{
    bytes->data[0] = (uint8_t)(value & 0xffu);
    bytes->data[1] = (uint8_t)((value >> 8) & 0xffu);
    bytes->data[2] = (uint8_t)((value >> 16) & 0xffu);
    bytes->data[3] = (uint8_t)((value >> 24) & 0xffu);
    return qemu_plugin_write_register(g.regs[index].handle, bytes) > 0;
}

static void maybe_inject_register_fault(uint64_t pc)
{
    if (g.done || !g.active_window || g.mode != MODE_REG_BITFLIP_WINDOW) {
        return;
    }
    if (g.fault.injected || g.reg_count == 0) {
        return;
    }

    g.window_insns_seen += 1;
    if (g.window_insns_seen < g.reg_inject_after) {
        return;
    }

    uint32_t before = 0;
    GByteArray *bytes = NULL;
    if (!read_register_u32(g.selected_reg, &before, &bytes)) {
        copy_str(g.fault.target_kind, sizeof(g.fault.target_kind), "reg-read-failed");
        copy_str(g.fault.target_name, sizeof(g.fault.target_name), g.regs[g.selected_reg].name);
        return;
    }

    uint32_t bit = g.fault.bit;
    uint32_t after = before ^ (UINT32_C(1) << bit);
    bool ok = write_register_u32(g.selected_reg, bytes, after);
    g_byte_array_unref(bytes);

    g.fault.inject_pc = pc;
    g.fault.inject_offset = g.window_insns_seen;
    g.fault.before = before;
    g.fault.after = after;
    copy_str(g.fault.target_name, sizeof(g.fault.target_name), g.regs[g.selected_reg].name);

    if (!ok) {
        copy_str(g.fault.target_kind, sizeof(g.fault.target_kind), "reg-write-failed");
        return;
    }

    g.fault.injected = true;
    copy_str(g.fault.target_kind, sizeof(g.fault.target_kind), "reg");
}

static void prepare_register_fault(void)
{
    if (g.reg_count == 0) {
        copy_str(g.fault.target_kind, sizeof(g.fault.target_kind), "no-register");
        return;
    }
    g.window_insns_seen = 0;
    g.reg_inject_after = 1 + rng_bounded(64);
    g.selected_reg = rng_bounded((uint32_t)g.reg_count);
    g.fault.bit = rng_bounded(32);
    copy_str(g.fault.target_kind, sizeof(g.fault.target_kind), "reg-pending");
    copy_str(g.fault.target_name, sizeof(g.fault.target_name), g.regs[g.selected_reg].name);
}

static void mark_done(void)
{
    if (g.done) {
        return;
    }
    g.done = true;
    if (g.csv != NULL) {
        fflush(g.csv);
    }
    if (g.config.done_path[0] != '\0') {
        FILE *done = fopen(g.config.done_path, "w");
        if (done != NULL) {
            fprintf(done, "rows=%" PRIu32 "\n", g.rows_written);
            fclose(done);
        }
    }
}

static void write_csv_header(void)
{
    fprintf(g.csv,
            "technique,implementation,campaign,iteration,stage,"
            "fault_target,fault_value,initial_value,expected,status,"
            "restart_status,recovery_status,control_status,terminal_status,"
            "active_check,checkpoint_check,primary_check,restore_check,"
            "alternate_check,phase,signature,transitions,value,active_value,"
            "checkpoint_value,passes,failures,seed,fault_mode,inject_pc,"
            "inject_offset,target_kind,target_name,target_addr,bit,before,"
            "after,qemu_plugin_api\n");
    fflush(g.csv);
}

static void write_csv_row(void)
{
    uint32_t iteration = read_symbol_u32_or_zero("harness_iteration");
    uint32_t stage = read_symbol_u32_or_zero("harness_stage");
    uint32_t fault_target = read_symbol_u32_or_zero("harness_last_fault_target");
    uint32_t initial_value = read_symbol_u32_or_zero("harness_last_initial_value");
    uint32_t expected = read_symbol_u32_or_zero("harness_last_expected");
    uint32_t status = read_symbol_u32_or_zero("harness_last_status");
    uint32_t restart_status = read_symbol_u32_or_zero("harness_last_restart_status");
    uint32_t recovery_status = read_symbol_u32_or_zero("harness_last_recovery_status");
    uint32_t control_status = read_symbol_u32_or_zero("harness_last_control_status");
    uint32_t terminal_status = read_symbol_u32_or_zero("harness_last_terminal_status");
    uint32_t active_check = read_symbol_u32_or_zero("harness_last_active_check");
    uint32_t checkpoint_check = read_symbol_u32_or_zero("harness_last_checkpoint_check");
    uint32_t primary_check = read_symbol_u32_or_zero("harness_last_primary_check");
    uint32_t restore_check = read_symbol_u32_or_zero("harness_last_restore_check");
    uint32_t alternate_check = read_symbol_u32_or_zero("harness_last_alternate_check");
    uint32_t phase = read_symbol_u32_or_zero("harness_last_phase");
    uint32_t signature = read_symbol_u32_or_zero("harness_last_signature");
    uint32_t transitions = read_symbol_u32_or_zero("harness_last_transitions");
    uint32_t value = read_symbol_u32_or_zero("harness_last_value");
    uint32_t active_value = read_symbol_u32_or_zero("harness_last_active_value");
    uint32_t checkpoint_value = read_symbol_u32_or_zero("harness_last_checkpoint_value");
    uint32_t passes = read_symbol_u32_or_zero("harness_passes");
    uint32_t failures = read_symbol_u32_or_zero("harness_failures");

    if (g.fault.fault_target != 0 || g.fault.fault_value != 0) {
        fault_target = g.fault.fault_target;
    }

    fprintf(g.csv,
            "%s,%s,%s,%" PRIu32 ",%" PRIu32 ","
            "%" PRIu32 ",%" PRIu32 ",%" PRIu32 ",%" PRIu32 ",%" PRIu32 ","
            "%" PRIu32 ",%" PRIu32 ",%" PRIu32 ",%" PRIu32 ","
            "%" PRIu32 ",%" PRIu32 ",%" PRIu32 ",%" PRIu32 ","
            "%" PRIu32 ",%" PRIu32 ",%" PRIu32 ",%" PRIu32 ",%" PRIu32 ",%" PRIu32 ","
            "%" PRIu32 ",%" PRIu32 ",%" PRIu32 ",%" PRIu64 ",%s,0x%" PRIx64 ","
            "%" PRIu64 ",%s,%s,0x%" PRIx64 ",%" PRIu32 ",%" PRIu32 ","
            "%" PRIu32 ",%d\n",
            g.config.technique,
            g.config.language,
            g.config.campaign,
            iteration,
            stage,
            fault_target,
            g.fault.fault_value,
            initial_value,
            expected,
            status,
            restart_status,
            recovery_status,
            control_status,
            terminal_status,
            active_check,
            checkpoint_check,
            primary_check,
            restore_check,
            alternate_check,
            phase,
            signature,
            transitions,
            value,
            active_value,
            checkpoint_value,
            passes,
            failures,
            g.config.seed,
            g.fault.fault_mode,
            g.fault.inject_pc,
            g.fault.inject_offset,
            g.fault.target_kind,
            g.fault.target_name,
            g.fault.target_addr,
            g.fault.bit,
            g.fault.before,
            g.fault.after,
            QEMU_PLUGIN_VERSION);
    fflush(g.csv);
}

static void on_start_hook(unsigned int vcpu_index, void *userdata)
{
    (void)vcpu_index;
    (void)userdata;

    if (g.done) {
        return;
    }

    reset_fault_record();
    g.active_window = true;
    uint32_t iteration = read_symbol_u32_or_zero("harness_iteration");

    switch (g.mode) {
    case MODE_NONE:
        break;
    case MODE_ABI_NONE:
    case MODE_ABI_MIXED:
        inject_abi_fault(iteration);
        break;
    case MODE_RAM_SYMBOL_BITFLIP:
        inject_ram_symbol_fault();
        break;
    case MODE_REG_BITFLIP_WINDOW:
        prepare_register_fault();
        break;
    }
}

static void on_end_hook(unsigned int vcpu_index, void *userdata)
{
    (void)vcpu_index;
    (void)userdata;

    if (g.done) {
        return;
    }

    g.active_window = false;
    if (g.csv != NULL) {
        write_csv_row();
    }
    g.rows_written += 1;
    if (g.rows_written >= g.config.iterations) {
        mark_done();
    }
}

static void on_instruction(unsigned int vcpu_index, void *userdata)
{
    (void)vcpu_index;
    uint64_t pc = (uint64_t)(uintptr_t)userdata;
    maybe_inject_register_fault(pc);
}

static void on_tb_trans(qemu_plugin_id_t id, struct qemu_plugin_tb *tb)
{
    (void)id;
    size_t insn_count = qemu_plugin_tb_n_insns(tb);
    for (size_t i = 0; i < insn_count; i++) {
        struct qemu_plugin_insn *insn = qemu_plugin_tb_get_insn(tb, i);
        uint64_t pc = qemu_plugin_insn_vaddr(insn);

        if (pc == g.config.start_pc) {
            qemu_plugin_register_vcpu_insn_exec_cb(
                insn, on_start_hook, QEMU_PLUGIN_CB_NO_REGS, NULL);
        }
        if (pc == g.config.end_pc) {
            qemu_plugin_register_vcpu_insn_exec_cb(
                insn, on_end_hook, QEMU_PLUGIN_CB_NO_REGS, NULL);
        }

        if (g.mode == MODE_REG_BITFLIP_WINDOW
            && pc >= g.config.text_start
            && pc < g.config.text_end
            && pc != g.config.start_pc
            && pc != g.config.end_pc) {
            qemu_plugin_register_vcpu_insn_exec_cb(
                insn,
                on_instruction,
                QEMU_PLUGIN_CB_RW_REGS,
                (void *)(uintptr_t)pc);
        }
    }
}

static bool is_general_arm_reg(const char *name)
{
    if (name[0] != 'r') {
        return false;
    }
    if (name[1] >= '0' && name[1] <= '9' && name[2] == '\0') {
        return true;
    }
    if (name[1] == '1' && name[2] >= '0' && name[2] <= '2' && name[3] == '\0') {
        return true;
    }
    return false;
}

static void on_vcpu_init(qemu_plugin_id_t id, unsigned int vcpu_index)
{
    (void)id;
    (void)vcpu_index;

    GArray *registers = qemu_plugin_get_registers();
    if (registers == NULL) {
        return;
    }

    for (guint i = 0; i < registers->len && g.reg_count < MAX_REGS; i++) {
        qemu_plugin_reg_descriptor *desc =
            &g_array_index(registers, qemu_plugin_reg_descriptor, i);
        if (desc->name == NULL || desc->handle == NULL) {
            continue;
        }
        if (!is_general_arm_reg(desc->name)) {
            continue;
        }
        copy_str(g.regs[g.reg_count].name, sizeof(g.regs[g.reg_count].name), desc->name);
        g.regs[g.reg_count].handle = desc->handle;
        g.reg_count += 1;
    }

    g_array_free(registers, TRUE);
}

static void on_atexit(qemu_plugin_id_t id, void *userdata)
{
    (void)id;
    (void)userdata;
    if (g.csv != NULL) {
        fflush(g.csv);
        fclose(g.csv);
        g.csv = NULL;
    }
}

static bool parse_named_addr_value(const char *value, uint64_t *addr, uint64_t *size)
{
    char local[128];
    copy_str(local, sizeof(local), value);
    char *sep = strchr(local, ':');
    if (sep == NULL) {
        *size = 0;
        return parse_u64(local, addr);
    }
    *sep = '\0';
    sep++;
    return parse_u64(trim(local), addr) && parse_u64(trim(sep), size);
}

static bool parse_manifest_line(char *line, Config *config)
{
    char *trimmed = trim(line);
    if (*trimmed == '\0' || *trimmed == '#') {
        return true;
    }

    char *eq = strchr(trimmed, '=');
    if (eq == NULL) {
        return false;
    }
    *eq = '\0';
    char *key = trim(trimmed);
    char *value = trim(eq + 1);

    if (strcmp(key, "technique") == 0) {
        copy_str(config->technique, sizeof(config->technique), value);
        return true;
    }
    if (strcmp(key, "language") == 0) {
        copy_str(config->language, sizeof(config->language), value);
        return true;
    }
    if (strcmp(key, "campaign") == 0) {
        copy_str(config->campaign, sizeof(config->campaign), value);
        return true;
    }
    if (strcmp(key, "csv") == 0) {
        copy_str(config->csv_path, sizeof(config->csv_path), value);
        return true;
    }
    if (strcmp(key, "done") == 0) {
        copy_str(config->done_path, sizeof(config->done_path), value);
        return true;
    }
    if (strcmp(key, "seed") == 0) {
        return parse_u64(value, &config->seed);
    }
    if (strcmp(key, "iterations") == 0) {
        uint64_t iterations = 0;
        if (!parse_u64(value, &iterations)) {
            return false;
        }
        config->iterations = (uint32_t)iterations;
        return true;
    }
    if (strcmp(key, "start_pc") == 0) {
        return parse_u64(value, &config->start_pc);
    }
    if (strcmp(key, "end_pc") == 0) {
        return parse_u64(value, &config->end_pc);
    }
    if (strcmp(key, "text_start") == 0) {
        return parse_u64(value, &config->text_start);
    }
    if (strcmp(key, "text_end") == 0) {
        return parse_u64(value, &config->text_end);
    }
    if (strncmp(key, "sym.", 4) == 0) {
        NamedAddress *symbol = append_named_address(
            config->symbols, &config->symbol_count, MAX_SYMBOLS, key + 4);
        if (symbol == NULL) {
            return false;
        }
        return parse_named_addr_value(value, &symbol->addr, &symbol->size);
    }
    if (strncmp(key, "fuzz.", 5) == 0) {
        NamedAddress *symbol = append_named_address(
            config->fuzz_symbols, &config->fuzz_symbol_count, MAX_FUZZ_SYMBOLS, key + 5);
        if (symbol == NULL) {
            return false;
        }
        return parse_named_addr_value(value, &symbol->addr, &symbol->size);
    }

    return true;
}

static bool parse_manifest(const char *path, Config *config)
{
    FILE *file = fopen(path, "r");
    if (file == NULL) {
        plugin_log2("qemu-ft-fuzz: could not open manifest: ", path);
        return false;
    }

    char line[1024];
    unsigned int line_no = 0;
    while (fgets(line, sizeof(line), file) != NULL) {
        line_no += 1;
        if (!parse_manifest_line(line, config)) {
            char msg[256];
            snprintf(msg, sizeof(msg), "qemu-ft-fuzz: invalid manifest line %u\n", line_no);
            plugin_log(msg);
            fclose(file);
            return false;
        }
    }

    fclose(file);
    return true;
}

static bool validate_config(const Config *config)
{
    if (config->technique[0] == '\0' || config->language[0] == '\0'
        || config->campaign[0] == '\0' || config->csv_path[0] == '\0'
        || config->done_path[0] == '\0' || config->iterations == 0
        || config->start_pc == 0 || config->end_pc == 0) {
        plugin_log("qemu-ft-fuzz: manifest missing required fields\n");
        return false;
    }
    return true;
}

QEMU_PLUGIN_EXPORT int qemu_plugin_install(qemu_plugin_id_t id,
                                           const qemu_info_t *info,
                                           int argc,
                                           char **argv)
{
    memset(&g, 0, sizeof(g));
    g.id = id;

    if (info == NULL || !info->system_emulation) {
        plugin_log("qemu-ft-fuzz: this plugin requires system emulation\n");
        return -1;
    }
    if (info->version.cur < 5) {
        plugin_log("qemu-ft-fuzz: QEMU plugin API version 5 or newer is required\n");
        return -1;
    }

    const char *manifest = NULL;
    for (int i = 0; i < argc; i++) {
        if (strncmp(argv[i], "manifest=", 9) == 0) {
            manifest = argv[i] + 9;
        }
    }
    if (manifest == NULL) {
        plugin_log("qemu-ft-fuzz: missing manifest=<path> argument\n");
        return -1;
    }

    if (!parse_manifest(manifest, &g.config) || !validate_config(&g.config)) {
        return -1;
    }

    g.technique = parse_technique(g.config.technique);
    g.mode = parse_mode(g.config.campaign);
    g.rng_state = g.config.seed;
    if (g.rng_state == 0) {
        g.rng_state = UINT64_C(0x4d595df4d0f33173);
    }
    if (g.config.text_end == 0) {
        g.config.text_end = UINT64_MAX;
    }

    g.csv = fopen(g.config.csv_path, "w");
    if (g.csv == NULL) {
        plugin_log2("qemu-ft-fuzz: could not open csv: ", g.config.csv_path);
        return -1;
    }
    write_csv_header();

    qemu_plugin_register_vcpu_init_cb(id, on_vcpu_init);
    qemu_plugin_register_vcpu_tb_trans_cb(id, on_tb_trans);
    qemu_plugin_register_atexit_cb(id, on_atexit, NULL);

    plugin_log("qemu-ft-fuzz: installed\n");
    return 0;
}

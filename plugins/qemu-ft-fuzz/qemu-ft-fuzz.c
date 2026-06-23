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
#define MAX_FUZZ_SYMBOLS 64
#define MAX_REGS 16

typedef enum {
  MODE_NONE,
  MODE_RAM_SYMBOL_BITFLIP,
  MODE_REG_BITFLIP_WINDOW,
  MODE_INSN_SKIP,
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
  char fault_mode[64];
  char fault_domain[32];
  uint64_t campaign_seed;
  uint64_t trial_seed;
  uint32_t trial_id;
  uint64_t max_instructions;
  uint64_t window_skip_bound;
  uint64_t entry_pc;
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
} FaultRecord;

typedef struct {
  qemu_plugin_id_t id;
  Config config;
  FaultMode mode;
  bool done;
  bool seed_written;
  bool raw_result_written;
  bool instruction_budget_exhausted;
  bool active_window;
  uint64_t rng_state;
  uint64_t instructions_executed;
  uint64_t window_insns_seen;
  uint64_t window_insns_total;
  uint64_t reg_inject_after;
  uint64_t insn_skip_after;
  size_t selected_reg;
  RegisterHandle regs[MAX_REGS];
  size_t reg_count;
  struct qemu_plugin_register *pc_handle;
  FaultRecord fault;
} PluginState;

static PluginState g;

static void plugin_log(const char *message) { qemu_plugin_outs(message); }

static void plugin_log2(const char *prefix, const char *value) {
  char buf[1024];
  snprintf(buf, sizeof(buf), "%s%s\n", prefix, value);
  qemu_plugin_outs(buf);
}

static char *trim(char *value) {
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

static bool parse_u64(const char *value, uint64_t *out) {
  errno = 0;
  char *end = NULL;
  uint64_t parsed = strtoull(value, &end, 0);
  if (errno != 0 || end == value || *trim(end) != '\0') {
    return false;
  }
  *out = parsed;
  return true;
}

static void copy_str(char *dest, size_t dest_size, const char *src) {
  if (dest_size != 0) {
    snprintf(dest, dest_size, "%s", src);
  }
}

static NamedAddress *append_named_address(NamedAddress *items, size_t *count,
                                          size_t max_count, const char *name) {
  if (*count >= max_count) {
    return NULL;
  }
  NamedAddress *item = &items[*count];
  memset(item, 0, sizeof(*item));
  copy_str(item->name, sizeof(item->name), name);
  *count += 1;
  return item;
}

static NamedAddress *find_symbol(const char *name) {
  for (size_t i = 0; i < g.config.symbol_count; i++) {
    if (strcmp(g.config.symbols[i].name, name) == 0) {
      return &g.config.symbols[i];
    }
  }
  return NULL;
}

static bool read_u32_addr(uint64_t addr, uint32_t *out) {
  GByteArray *bytes = g_byte_array_sized_new(sizeof(uint32_t));
  enum qemu_plugin_hwaddr_operation_result result =
      qemu_plugin_read_memory_hwaddr(addr, bytes, sizeof(uint32_t));
  if (result != QEMU_PLUGIN_HWADDR_OPERATION_OK ||
      bytes->len < sizeof(uint32_t)) {
    g_byte_array_unref(bytes);
    return false;
  }

  const uint8_t *data = bytes->data;
  *out = ((uint32_t)data[0]) | ((uint32_t)data[1] << 8) |
         ((uint32_t)data[2] << 16) | ((uint32_t)data[3] << 24);
  g_byte_array_unref(bytes);
  return true;
}

static bool write_u32_addr(uint64_t addr, uint32_t value) {
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

static bool write_u64_addr(uint64_t addr, uint64_t value) {
  uint8_t raw[sizeof(uint64_t)] = {
      (uint8_t)(value & 0xffu),         (uint8_t)((value >> 8) & 0xffu),
      (uint8_t)((value >> 16) & 0xffu), (uint8_t)((value >> 24) & 0xffu),
      (uint8_t)((value >> 32) & 0xffu), (uint8_t)((value >> 40) & 0xffu),
      (uint8_t)((value >> 48) & 0xffu), (uint8_t)((value >> 56) & 0xffu),
  };
  GByteArray *bytes = g_byte_array_sized_new(sizeof(raw));
  g_byte_array_append(bytes, raw, sizeof(raw));
  enum qemu_plugin_hwaddr_operation_result result =
      qemu_plugin_write_memory_hwaddr(addr, bytes);
  g_byte_array_unref(bytes);
  return result == QEMU_PLUGIN_HWADDR_OPERATION_OK;
}

static uint32_t read_symbol_u32_or_zero(const char *name) {
  uint32_t value = 0;
  NamedAddress *symbol = find_symbol(name);
  if (symbol != NULL) {
    (void)read_u32_addr(symbol->addr, &value);
  }
  return value;
}

static bool write_symbol_u64(const char *name, uint64_t value) {
  NamedAddress *symbol = find_symbol(name);
  return symbol != NULL && write_u64_addr(symbol->addr, value);
}

static uint64_t rng_next(void) {
  uint64_t x = g.rng_state;
  x ^= x >> 12;
  x ^= x << 25;
  x ^= x >> 27;
  g.rng_state = x;
  return x * UINT64_C(2685821657736338717);
}

static uint32_t rng_bounded(uint32_t bound) {
  return bound == 0 ? 0 : (uint32_t)(rng_next() % bound);
}

static FaultMode parse_mode(const char *value) {
  if (strcmp(value, "none") == 0) {
    return MODE_NONE;
  }
  if (strcmp(value, "ram-bitflip") == 0) {
    return MODE_RAM_SYMBOL_BITFLIP;
  }
  if (strcmp(value, "reg-bitflip") == 0) {
    return MODE_REG_BITFLIP_WINDOW;
  }
  if (strcmp(value, "insn-skip") == 0) {
    return MODE_INSN_SKIP;
  }
  return MODE_NONE;
}

static const char *mode_name(FaultMode mode) {
  switch (mode) {
  case MODE_NONE:
    return "none";
  case MODE_RAM_SYMBOL_BITFLIP:
    return "ram-bitflip";
  case MODE_REG_BITFLIP_WINDOW:
    return "reg-bitflip";
  case MODE_INSN_SKIP:
    return "insn-skip";
  }
  return "unknown";
}

static void reset_fault_record(void) {
  memset(&g.fault, 0, sizeof(g.fault));
  copy_str(g.fault.fault_mode, sizeof(g.fault.fault_mode), mode_name(g.mode));
  copy_str(g.fault.target_kind, sizeof(g.fault.target_kind), "none");
}

static void inject_ram_symbol_fault(uint64_t pc) {
  if (g.config.fuzz_symbol_count == 0) {
    copy_str(g.fault.target_kind, sizeof(g.fault.target_kind),
             "no-fuzz-symbol");
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

  g.fault.inject_pc = pc;
  g.fault.inject_offset = word_index * sizeof(uint32_t);
  g.fault.target_addr = addr;
  g.fault.bit = bit;
  copy_str(g.fault.target_name, sizeof(g.fault.target_name), symbol->name);

  if (!read_u32_addr(addr, &before)) {
    copy_str(g.fault.target_kind, sizeof(g.fault.target_kind),
             "ram-read-failed");
    return;
  }

  uint32_t after = before ^ (UINT32_C(1) << bit);
  g.fault.before = before;
  g.fault.after = after;

  if (!write_u32_addr(addr, after)) {
    copy_str(g.fault.target_kind, sizeof(g.fault.target_kind),
             "ram-write-failed");
    return;
  }

  g.fault.injected = true;
  copy_str(g.fault.target_kind, sizeof(g.fault.target_kind), "ram-symbol");
}

static bool read_register_u32(struct qemu_plugin_register *handle,
                              uint32_t *out, GByteArray **out_bytes) {
  GByteArray *bytes = g_byte_array_sized_new(sizeof(uint32_t));
  int len = qemu_plugin_read_register(handle, bytes);
  if (len < (int)sizeof(uint32_t) || bytes->len < sizeof(uint32_t)) {
    g_byte_array_unref(bytes);
    return false;
  }

  const uint8_t *data = bytes->data;
  *out = ((uint32_t)data[0]) | ((uint32_t)data[1] << 8) |
         ((uint32_t)data[2] << 16) | ((uint32_t)data[3] << 24);
  *out_bytes = bytes;
  return true;
}

static bool write_register_u32(struct qemu_plugin_register *handle,
                               GByteArray *bytes, uint32_t value) {
  bytes->data[0] = (uint8_t)(value & 0xffu);
  bytes->data[1] = (uint8_t)((value >> 8) & 0xffu);
  bytes->data[2] = (uint8_t)((value >> 16) & 0xffu);
  bytes->data[3] = (uint8_t)((value >> 24) & 0xffu);
  return qemu_plugin_write_register(handle, bytes) > 0;
}

// Defined later (alongside the result emitter); streams the injection-site
// keys as soon as a fault lands so an aborting trial still records them.
static void emit_fault_location(void);

// window_skip_offset draws the 1-based index of the windowed instruction at
// which to inject. The bound comes from the manifest's measured window length
// (window_skip_bound); when absent it falls back to 16. Shared by the
// register-bitflip and instruction-skip modes.
static uint64_t window_skip_offset(void) {
  uint64_t bound = g.config.window_skip_bound != 0 ? g.config.window_skip_bound
                                                   : UINT64_C(16);
  if (bound > UINT32_MAX) {
    bound = UINT32_MAX;
  }
  return 1 + rng_bounded((uint32_t)bound);
}

static void prepare_register_fault(void) {
  if (g.reg_count == 0) {
    copy_str(g.fault.target_kind, sizeof(g.fault.target_kind), "no-register");
    return;
  }
  g.window_insns_seen = 0;
  g.reg_inject_after = window_skip_offset();
  g.selected_reg = rng_bounded((uint32_t)g.reg_count);
  g.fault.bit = rng_bounded(32);
  copy_str(g.fault.target_kind, sizeof(g.fault.target_kind), "reg-pending");
  copy_str(g.fault.target_name, sizeof(g.fault.target_name),
           g.regs[g.selected_reg].name);
}

static void maybe_inject_register_fault(uint64_t pc) {
  if (!g.active_window || g.mode != MODE_REG_BITFLIP_WINDOW ||
      g.fault.injected || g.reg_count == 0) {
    return;
  }

  g.window_insns_seen += 1;
  if (g.window_insns_seen < g.reg_inject_after) {
    return;
  }

  uint32_t before = 0;
  GByteArray *bytes = NULL;
  if (!read_register_u32(g.regs[g.selected_reg].handle, &before, &bytes)) {
    copy_str(g.fault.target_kind, sizeof(g.fault.target_kind),
             "reg-read-failed");
    return;
  }

  uint32_t after = before ^ (UINT32_C(1) << g.fault.bit);
  bool ok = write_register_u32(g.regs[g.selected_reg].handle, bytes, after);
  g_byte_array_unref(bytes);

  g.fault.inject_pc = pc;
  g.fault.inject_offset = g.window_insns_seen;
  g.fault.before = before;
  g.fault.after = after;
  copy_str(g.fault.target_name, sizeof(g.fault.target_name),
           g.regs[g.selected_reg].name);

  if (!ok) {
    copy_str(g.fault.target_kind, sizeof(g.fault.target_kind),
             "reg-write-failed");
    return;
  }

  g.fault.injected = true;
  copy_str(g.fault.target_kind, sizeof(g.fault.target_kind), "reg");
  emit_fault_location();
}

static void prepare_insn_skip(void) {
  if (g.pc_handle == NULL) {
    copy_str(g.fault.target_kind, sizeof(g.fault.target_kind), "no-pc-handle");
    return;
  }
  g.window_insns_seen = 0;
  g.insn_skip_after = window_skip_offset();
  copy_str(g.fault.target_kind, sizeof(g.fault.target_kind), "insn-skip-pending");
  copy_str(g.fault.target_name, sizeof(g.fault.target_name), "pc");
}

static void maybe_inject_insn_skip(uint64_t pc, uint64_t size) {
  if (!g.active_window || g.mode != MODE_INSN_SKIP || g.fault.injected ||
      g.pc_handle == NULL) {
    return;
  }

  g.window_insns_seen += 1;
  if (g.window_insns_seen < g.insn_skip_after) {
    return;
  }

  uint32_t before = 0;
  GByteArray *bytes = NULL;
  if (!read_register_u32(g.pc_handle, &before, &bytes)) {
    copy_str(g.fault.target_kind, sizeof(g.fault.target_kind),
             "pc-read-failed");
    return;
  }

  uint32_t after = (uint32_t)(pc + size);
  bool ok = write_register_u32(g.pc_handle, bytes, after);
  g_byte_array_unref(bytes);

  g.fault.inject_pc = pc;
  g.fault.inject_offset = g.window_insns_seen;
  g.fault.target_addr = pc + size;
  g.fault.before = before;
  g.fault.after = after;
  copy_str(g.fault.target_name, sizeof(g.fault.target_name), "pc");

  if (!ok) {
    copy_str(g.fault.target_kind, sizeof(g.fault.target_kind),
             "pc-write-failed");
    return;
  }

  g.fault.injected = true;
  copy_str(g.fault.target_kind, sizeof(g.fault.target_kind), "insn-skip");
  emit_fault_location();
}

// FT_RESULT_TAG prefixes every result key=value line on stderr; FT_RESULT_END
// is the sentinel marking a complete record. The Go runner scans the captured
// QEMU stderr for these (see fuzz.parseStderrFacts / RunQemuTrial) instead of
// reading a per-trial result file.
#define FT_RESULT_TAG "@@FT "
#define FT_RESULT_END "@@FT-END"

// emit_fault_location streams just the injection-site keys the moment a fault
// lands, so a trial that later aborts (e.g. a Cortex-M lockup -> SIGABRT)
// still reports where it skipped. The final record re-emits these; the Go
// side merges @@FT lines last-wins, so the duplicate is harmless.
static void emit_fault_location(void) {
  fprintf(stderr, FT_RESULT_TAG "injected=%u\n", g.fault.injected ? 1u : 0u);
  fprintf(stderr, FT_RESULT_TAG "target_kind=%s\n", g.fault.target_kind);
  fprintf(stderr, FT_RESULT_TAG "target_name=%s\n", g.fault.target_name);
  fprintf(stderr, FT_RESULT_TAG "target_addr=0x%" PRIx64 "\n",
          g.fault.target_addr);
  fprintf(stderr, FT_RESULT_TAG "inject_pc=0x%" PRIx64 "\n", g.fault.inject_pc);
  fprintf(stderr, FT_RESULT_TAG "inject_offset=%" PRIu64 "\n",
          g.fault.inject_offset);
  fflush(stderr);
}

static void write_raw_result(const char *plugin_status) {
  if (g.raw_result_written) {
    return;
  }

  fprintf(stderr, FT_RESULT_TAG "technique=%s\n", g.config.technique);
  fprintf(stderr, FT_RESULT_TAG "implementation=%s\n", g.config.language);
  fprintf(stderr, FT_RESULT_TAG "campaign=%s\n", g.config.campaign);
  fprintf(stderr, FT_RESULT_TAG "campaign_seed=0x%" PRIx64 "\n",
          g.config.campaign_seed);
  fprintf(stderr, FT_RESULT_TAG "trial_id=%" PRIu32 "\n", g.config.trial_id);
  fprintf(stderr, FT_RESULT_TAG "trial_seed=0x%" PRIx64 "\n",
          g.config.trial_seed);
  fprintf(stderr, FT_RESULT_TAG "harness_done=%" PRIu32 "\n",
          read_symbol_u32_or_zero("harness_done"));
  fprintf(stderr, FT_RESULT_TAG "harness_detected=%" PRIu32 "\n",
          read_symbol_u32_or_zero("harness_detected"));
  fprintf(stderr, FT_RESULT_TAG "harness_corrected=%" PRIu32 "\n",
          read_symbol_u32_or_zero("harness_corrected"));
  fprintf(stderr, FT_RESULT_TAG "harness_safe_state=%" PRIu32 "\n",
          read_symbol_u32_or_zero("harness_safe_state"));
  fprintf(stderr, FT_RESULT_TAG "harness_output=%" PRIu32 "\n",
          read_symbol_u32_or_zero("harness_output"));
  fprintf(stderr, FT_RESULT_TAG "harness_expected=%" PRIu32 "\n",
          read_symbol_u32_or_zero("harness_expected"));
  fprintf(stderr, FT_RESULT_TAG "harness_error_code=%" PRIu32 "\n",
          read_symbol_u32_or_zero("harness_error_code"));
  fprintf(stderr, FT_RESULT_TAG "harness_fault_window_open=%" PRIu32 "\n",
          read_symbol_u32_or_zero("harness_fault_window_open"));
  fprintf(stderr, FT_RESULT_TAG "injected=%u\n", g.fault.injected ? 1u : 0u);
  fprintf(stderr, FT_RESULT_TAG "fault_mode=%s\n", g.fault.fault_mode);
  fprintf(stderr, FT_RESULT_TAG "fault_domain=%s\n", g.config.fault_domain);
  fprintf(stderr, FT_RESULT_TAG "target_kind=%s\n", g.fault.target_kind);
  fprintf(stderr, FT_RESULT_TAG "target_name=%s\n", g.fault.target_name);
  fprintf(stderr, FT_RESULT_TAG "target_addr=0x%" PRIx64 "\n",
          g.fault.target_addr);
  fprintf(stderr, FT_RESULT_TAG "inject_pc=0x%" PRIx64 "\n", g.fault.inject_pc);
  fprintf(stderr, FT_RESULT_TAG "inject_offset=%" PRIu64 "\n",
          g.fault.inject_offset);
  fprintf(stderr, FT_RESULT_TAG "bit=%" PRIu32 "\n", g.fault.bit);
  fprintf(stderr, FT_RESULT_TAG "before=%" PRIu32 "\n", g.fault.before);
  fprintf(stderr, FT_RESULT_TAG "after=%" PRIu32 "\n", g.fault.after);
  fprintf(stderr, FT_RESULT_TAG "window_insns_total=%" PRIu64 "\n",
          g.window_insns_total);
  fprintf(stderr, FT_RESULT_TAG "instructions_executed=%" PRIu64 "\n",
          g.instructions_executed);
  fprintf(stderr, FT_RESULT_TAG "instruction_budget_exhausted=%u\n",
          g.instruction_budget_exhausted ? 1u : 0u);
  fprintf(stderr, FT_RESULT_TAG "qemu_plugin_api=%d\n", QEMU_PLUGIN_VERSION);
  fprintf(stderr, FT_RESULT_TAG "plugin_status=%s\n", plugin_status);
  fprintf(stderr, FT_RESULT_END "\n");
  fflush(stderr);
  g.raw_result_written = true;
}

static void mark_done(void) {
  if (g.done) {
    return;
  }
  g.done = true;
}

static void ensure_seed_written(uint64_t pc) {
  if (g.seed_written || pc != g.config.entry_pc) {
    return;
  }
  if (!write_symbol_u64("harness_trial_seed", g.config.trial_seed)) {
    plugin_log("qemu-ft-fuzz: failed to write harness_trial_seed\n");
  }
  g.seed_written = true;
}

static void handle_fault_window(uint64_t pc, uint64_t size) {
  uint32_t open = read_symbol_u32_or_zero("harness_fault_window_open");

  if (open != 0u && !g.active_window) {
    g.active_window = true;
    reset_fault_record();
    switch (g.mode) {
    case MODE_NONE:
      break;
    case MODE_RAM_SYMBOL_BITFLIP:
      inject_ram_symbol_fault(pc);
      break;
    case MODE_REG_BITFLIP_WINDOW:
      prepare_register_fault();
      break;
    case MODE_INSN_SKIP:
      prepare_insn_skip();
      break;
    }
  }

  if (open != 0u) {
    // Counts every instruction executed while the window is open, independent
    // of mode or injection. With fault_mode=none this measures the clean
    // window length used to bound windowed-offset campaigns.
    g.window_insns_total += 1;
    maybe_inject_register_fault(pc);
    maybe_inject_insn_skip(pc, size);
  } else {
    g.active_window = false;
  }
}

static void on_instruction(unsigned int vcpu_index, void *userdata) {
  (void)vcpu_index;
  uint64_t packed = (uint64_t)(uintptr_t)userdata;
  uint64_t pc = packed >> 3;
  uint64_t size = (packed & 1u) ? 4u : 2u;

  if (g.done) {
    return;
  }

  g.instructions_executed += 1;
  ensure_seed_written(pc);

  if (g.config.max_instructions != 0 &&
      g.instructions_executed > g.config.max_instructions) {
    g.instruction_budget_exhausted = true;
    write_raw_result("instruction_budget_exhausted");
    mark_done();
    return;
  }

  handle_fault_window(pc, size);

  if (read_symbol_u32_or_zero("harness_done") != 0u) {
    write_raw_result("completed");
    mark_done();
  }
}

static void on_tb_trans(qemu_plugin_id_t id, struct qemu_plugin_tb *tb) {
  (void)id;
  size_t insn_count = qemu_plugin_tb_n_insns(tb);
  for (size_t i = 0; i < insn_count; i++) {
    struct qemu_plugin_insn *insn = qemu_plugin_tb_get_insn(tb, i);
    uint64_t pc = qemu_plugin_insn_vaddr(insn);
    if (pc < g.config.text_start || pc >= g.config.text_end) {
      continue;
    }
    size_t size = qemu_plugin_insn_size(insn);
    uint64_t packed = (pc << 3) | (size == 4 ? 1u : 0u);
    enum qemu_plugin_cb_flags flags =
        (g.mode == MODE_REG_BITFLIP_WINDOW || g.mode == MODE_INSN_SKIP)
            ? QEMU_PLUGIN_CB_RW_REGS
            : QEMU_PLUGIN_CB_NO_REGS;
    qemu_plugin_register_vcpu_insn_exec_cb(insn, on_instruction, flags,
                                           (void *)(uintptr_t)packed);
  }
}

static bool is_general_arm_reg(const char *name) {
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

static void on_vcpu_init(qemu_plugin_id_t id, unsigned int vcpu_index) {
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
    if (g.pc_handle == NULL && strcmp(desc->name, "pc") == 0) {
      g.pc_handle = desc->handle;
    }
    if (!is_general_arm_reg(desc->name)) {
      continue;
    }
    copy_str(g.regs[g.reg_count].name, sizeof(g.regs[g.reg_count].name),
             desc->name);
    g.regs[g.reg_count].handle = desc->handle;
    g.reg_count += 1;
  }

  g_array_free(registers, TRUE);
}

static bool parse_named_addr_value(const char *value, uint64_t *addr,
                                   uint64_t *size) {
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

static bool parse_manifest_line(char *line, Config *config) {
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
  if (strcmp(key, "language") == 0 || strcmp(key, "implementation") == 0) {
    copy_str(config->language, sizeof(config->language), value);
    return true;
  }
  if (strcmp(key, "campaign") == 0) {
    copy_str(config->campaign, sizeof(config->campaign), value);
    return true;
  }
  if (strcmp(key, "fault_mode") == 0) {
    copy_str(config->fault_mode, sizeof(config->fault_mode), value);
    return true;
  }
  if (strcmp(key, "fault_domain") == 0) {
    copy_str(config->fault_domain, sizeof(config->fault_domain), value);
    return true;
  }
  if (strcmp(key, "campaign_seed") == 0) {
    return parse_u64(value, &config->campaign_seed);
  }
  if (strcmp(key, "trial_seed") == 0 || strcmp(key, "seed") == 0) {
    return parse_u64(value, &config->trial_seed);
  }
  if (strcmp(key, "trial_id") == 0) {
    uint64_t trial_id = 0;
    if (!parse_u64(value, &trial_id)) {
      return false;
    }
    config->trial_id = (uint32_t)trial_id;
    return true;
  }
  if (strcmp(key, "max_instructions") == 0) {
    return parse_u64(value, &config->max_instructions);
  }
  if (strcmp(key, "window_skip_bound") == 0) {
    return parse_u64(value, &config->window_skip_bound);
  }
  if (strcmp(key, "entry_pc") == 0) {
    return parse_u64(value, &config->entry_pc);
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
    return symbol != NULL &&
           parse_named_addr_value(value, &symbol->addr, &symbol->size);
  }
  if (strncmp(key, "fuzz.", 5) == 0) {
    NamedAddress *symbol =
        append_named_address(config->fuzz_symbols, &config->fuzz_symbol_count,
                             MAX_FUZZ_SYMBOLS, key + 5);
    return symbol != NULL &&
           parse_named_addr_value(value, &symbol->addr, &symbol->size);
  }

  return true;
}

static bool parse_manifest(const char *path, Config *config) {
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
      snprintf(msg, sizeof(msg), "qemu-ft-fuzz: invalid manifest line %u\n",
               line_no);
      plugin_log(msg);
      fclose(file);
      return false;
    }
  }

  fclose(file);
  return true;
}

static bool validate_config(const Config *config) {
  if (config->technique[0] == '\0' || config->language[0] == '\0' ||
      config->campaign[0] == '\0' || config->fault_mode[0] == '\0' ||
      config->fault_domain[0] == '\0' || config->entry_pc == 0 ||
      config->text_end <= config->text_start) {
    plugin_log("qemu-ft-fuzz: manifest missing required single-shot fields\n");
    return false;
  }
  if (find_symbol("harness_trial_seed") == NULL ||
      find_symbol("harness_done") == NULL ||
      find_symbol("harness_fault_window_open") == NULL) {
    plugin_log("qemu-ft-fuzz: manifest missing required ABI symbols\n");
    return false;
  }
  return true;
}

QEMU_PLUGIN_EXPORT int qemu_plugin_install(qemu_plugin_id_t id,
                                           const qemu_info_t *info, int argc,
                                           char **argv) {
  memset(&g, 0, sizeof(g));
  g.id = id;

  if (info == NULL || !info->system_emulation) {
    plugin_log("qemu-ft-fuzz: this plugin requires system emulation\n");
    return -1;
  }
  if (info->version.cur < 5) {
    plugin_log(
        "qemu-ft-fuzz: QEMU plugin API version 5 or newer is required\n");
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

  if (!parse_manifest(manifest, &g.config)) {
    return -1;
  }

  // Overlay per-trial key=value plugin args (trial_seed, trial_id,
  // window_skip_bound, and fault_mode for the probe) on top of the
  // campaign-static manifest, reusing the manifest line parser. manifest= is
  // consumed above; file= is stripped by QEMU and never reaches argv.
  for (int i = 0; i < argc; i++) {
    if (strncmp(argv[i], "manifest=", 9) == 0) {
      continue;
    }
    char arg[256];
    copy_str(arg, sizeof(arg), argv[i]);
    if (!parse_manifest_line(arg, &g.config)) {
      plugin_log2("qemu-ft-fuzz: invalid plugin arg: ", argv[i]);
      return -1;
    }
  }

  if (!validate_config(&g.config)) {
    return -1;
  }

  g.mode = parse_mode(g.config.fault_mode);
  g.rng_state = g.config.trial_seed;
  if (g.rng_state == 0) {
    g.rng_state = UINT64_C(0x4d595df4d0f33173);
  }
  reset_fault_record();

  qemu_plugin_register_vcpu_init_cb(id, on_vcpu_init);
  qemu_plugin_register_vcpu_tb_trans_cb(id, on_tb_trans);

  plugin_log("qemu-ft-fuzz: installed single-shot mode\n");
  return 0;
}

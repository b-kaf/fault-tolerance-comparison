#include <stdint.h>

#include "harness_abi.h"
#include "../../../c/recovery_block/recovery_block.h"

_Static_assert((int)RECOVERY_BLOCK_PRIMARY_ACCEPTED == HARNESS_RECOVERY_PRIMARY_ACCEPTED,
    "recovery_block_status_t::RECOVERY_BLOCK_PRIMARY_ACCEPTED must match HARNESS_RECOVERY_PRIMARY_ACCEPTED");
_Static_assert((int)RECOVERY_BLOCK_ALTERNATE_ACCEPTED == HARNESS_RECOVERY_ALTERNATE_ACCEPTED,
    "recovery_block_status_t::RECOVERY_BLOCK_ALTERNATE_ACCEPTED must match HARNESS_RECOVERY_ALTERNATE_ACCEPTED");
_Static_assert((int)RECOVERY_BLOCK_UNRECOVERABLE == HARNESS_RECOVERY_UNRECOVERABLE,
    "recovery_block_status_t::RECOVERY_BLOCK_UNRECOVERABLE must match HARNESS_RECOVERY_UNRECOVERABLE");
_Static_assert((int)RECOVERY_BLOCK_CHECKPOINT_FAILED == HARNESS_RECOVERY_CHECKPOINT_FAILED,
    "recovery_block_status_t::RECOVERY_BLOCK_CHECKPOINT_FAILED must match HARNESS_RECOVERY_CHECKPOINT_FAILED");
_Static_assert((int)RECOVERY_BLOCK_RESTORE_FAILED == HARNESS_RECOVERY_RESTORE_FAILED,
    "recovery_block_status_t::RECOVERY_BLOCK_RESTORE_FAILED must match HARNESS_RECOVERY_RESTORE_FAILED");

volatile uint32_t harness_iteration;
volatile uint32_t harness_stage;
volatile uint32_t harness_fault_target;
volatile uint32_t harness_fault_value;
volatile uint32_t harness_last_expected;
volatile uint32_t harness_last_initial_value;
volatile uint32_t harness_last_value;
volatile uint32_t harness_last_status;
volatile uint32_t harness_last_recovery_status;
volatile uint32_t harness_last_checkpoint_check;
volatile uint32_t harness_last_primary_check;
volatile uint32_t harness_last_restore_check;
volatile uint32_t harness_last_alternate_check;
volatile uint32_t harness_last_active_value;
volatile uint32_t harness_last_checkpoint_value;
volatile uint32_t harness_passes;
volatile uint32_t harness_failures;
volatile uint32_t harness_last_fault_target;
volatile checkpoint_record_t harness_c_recovery_block_state;

static uint32_t sample_initial_value(uint32_t iteration) {
    return 100u + ((iteration * 29u) % 700u);
}

static checker_record_t sample_record(uint32_t value) {
    return checker_record_init(
        CHECKER_TAG_SAMPLE,
        value,
        0u,
        1000u,
        6u,
        16u);
}

__attribute__((used, noinline))
void harness_injection_point_before_recovery(void) {
    __asm__ volatile("nop");
}

__attribute__((used, noinline))
void harness_injection_point_after_recovery(void) {
    __asm__ volatile("nop");
}

static void mirror_state(void) {
    const checkpoint_record_t *state =
        (const checkpoint_record_t *)&harness_c_recovery_block_state;
    harness_last_active_value = state->active.value;
    harness_last_checkpoint_value = state->checkpoint.value;
}

static void set_primary_value_fault(checkpoint_record_t *state) {
    state->active.value = harness_fault_value;
}

static void apply_after_primary_fault(checkpoint_record_t *state, void *context) {
    (void)context;

    harness_stage = HARNESS_STAGE_AFTER_PRIMARY;

    switch (harness_fault_target) {
    case HARNESS_FAULT_RECOVERY_PRIMARY_VALUE:
    case HARNESS_FAULT_RECOVERY_PRIMARY_VALUE_AND_ALTERNATE_CHECKSUM:
        set_primary_value_fault(state);
        break;
    case HARNESS_FAULT_RECOVERY_PRIMARY_CHECKSUM:
        state->active.checksum ^= harness_fault_value;
        break;
    case HARNESS_FAULT_RECOVERY_PRIMARY_VALUE_AND_CHECKPOINT_CHECKSUM:
        set_primary_value_fault(state);
        state->checkpoint.checksum ^= 0x10u;
        break;
    default:
        break;
    }

    mirror_state();
}

static void apply_after_alternate_fault(checkpoint_record_t *state, void *context) {
    (void)context;

    harness_stage = HARNESS_STAGE_AFTER_ALTERNATE;

    if (harness_fault_target ==
        HARNESS_FAULT_RECOVERY_PRIMARY_VALUE_AND_ALTERNATE_CHECKSUM) {
        state->active.checksum ^= 0x10u;
    }

    mirror_state();
}

static void increment_passes(void) {
    harness_passes += 1u;
}

static void increment_failures(void) {
    harness_failures += 1u;
}

static void validate(uint32_t initial, uint32_t expected) {
    const uint32_t target = harness_last_fault_target;
    const uint32_t recovery_status = harness_last_recovery_status;
    const uint32_t checkpoint_check = harness_last_checkpoint_check;
    const uint32_t primary_check = harness_last_primary_check;
    const uint32_t restore_check = harness_last_restore_check;
    const uint32_t alternate_check = harness_last_alternate_check;
    const uint32_t active_value = harness_last_active_value;
    const uint32_t checkpoint_value = harness_last_checkpoint_value;

    switch (target) {
    case HARNESS_FAULT_RECOVERY_PRIMARY_VALUE:
        if (recovery_status == HARNESS_RECOVERY_ALTERNATE_ACCEPTED &&
            checkpoint_check == CHECKER_OK &&
            primary_check == CHECKER_ERR_ABOVE_MAX &&
            restore_check == CHECKER_OK &&
            alternate_check == CHECKER_OK &&
            active_value == expected &&
            checkpoint_value == expected) {
            increment_passes();
        } else {
            increment_failures();
        }
        return;
    case HARNESS_FAULT_RECOVERY_PRIMARY_CHECKSUM:
        if (recovery_status == HARNESS_RECOVERY_ALTERNATE_ACCEPTED &&
            checkpoint_check == CHECKER_OK &&
            primary_check == CHECKER_ERR_INVALID_CHECKSUM &&
            restore_check == CHECKER_OK &&
            alternate_check == CHECKER_OK &&
            active_value == expected &&
            checkpoint_value == expected) {
            increment_passes();
        } else {
            increment_failures();
        }
        return;
    case HARNESS_FAULT_RECOVERY_PRIMARY_VALUE_AND_ALTERNATE_CHECKSUM:
        if (recovery_status == HARNESS_RECOVERY_UNRECOVERABLE &&
            checkpoint_check == CHECKER_OK &&
            primary_check == CHECKER_ERR_ABOVE_MAX &&
            restore_check == CHECKER_OK &&
            alternate_check == CHECKER_ERR_INVALID_CHECKSUM &&
            active_value == initial &&
            checkpoint_value == initial) {
            increment_passes();
        } else {
            increment_failures();
        }
        return;
    case HARNESS_FAULT_RECOVERY_PRIMARY_VALUE_AND_CHECKPOINT_CHECKSUM:
        if (recovery_status == HARNESS_RECOVERY_RESTORE_FAILED &&
            checkpoint_check == CHECKER_OK &&
            primary_check == CHECKER_ERR_ABOVE_MAX &&
            restore_check == CHECKER_ERR_INVALID_CHECKSUM &&
            alternate_check == CHECKER_OK &&
            active_value == harness_fault_value) {
            increment_passes();
        } else {
            increment_failures();
        }
        return;
    default:
        if (recovery_status == HARNESS_RECOVERY_PRIMARY_ACCEPTED &&
            checkpoint_check == CHECKER_OK &&
            primary_check == CHECKER_OK &&
            restore_check == CHECKER_OK &&
            alternate_check == CHECKER_OK &&
            active_value == expected &&
            checkpoint_value == expected) {
            increment_passes();
        } else {
            increment_failures();
        }
        return;
    }
}

void harness_main(void) {
    harness_stage = HARNESS_STAGE_BOOT;

    for (;;) {
        const uint32_t iteration = harness_iteration + 1u;
        const uint32_t initial = sample_initial_value(iteration);
        const uint32_t expected = recovery_block_sample_primary_value(iteration);
        const checker_record_t record = sample_record(initial);
        recovery_block_sample_update_t update = {
            iteration,
            RECOVERY_BLOCK_SAMPLE_FAULT_NONE,
        };
        recovery_block_result_t result;

        harness_iteration = iteration;
        harness_last_initial_value = initial;
        harness_last_expected = expected;
        harness_last_value = 0u;
        harness_last_status = HARNESS_RECOVERY_PRIMARY_ACCEPTED;
        harness_last_recovery_status = HARNESS_RECOVERY_PRIMARY_ACCEPTED;
        harness_last_checkpoint_check = CHECKER_OK;
        harness_last_primary_check = CHECKER_OK;
        harness_last_restore_check = CHECKER_OK;
        harness_last_alternate_check = CHECKER_OK;
        harness_last_fault_target = HARNESS_FAULT_NONE;
        harness_c_recovery_block_state = checkpoint_record_init(record);
        mirror_state();

        harness_stage = HARNESS_STAGE_BEFORE_RECOVERY;
        harness_injection_point_before_recovery();

        harness_last_fault_target = harness_fault_target;
        result = recovery_block_run_with_hooks(
            (checkpoint_record_t *)&harness_c_recovery_block_state,
            recovery_block_sample_primary,
            apply_after_primary_fault,
            recovery_block_sample_alternate,
            apply_after_alternate_fault,
            &update);

        harness_last_recovery_status = result.status;
        harness_last_status = result.status;
        harness_last_checkpoint_check = result.checkpoint_check;
        harness_last_primary_check = result.primary_check;
        harness_last_restore_check = result.restore_check;
        harness_last_alternate_check = result.alternate_check;
        mirror_state();
        harness_last_value = harness_last_active_value;
        harness_fault_target = HARNESS_FAULT_NONE;

        harness_stage = HARNESS_STAGE_AFTER_RECOVERY;
        validate(initial, expected);
        harness_injection_point_after_recovery();
    }
}

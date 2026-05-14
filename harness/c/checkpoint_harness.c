#include <stdint.h>

#include "harness_abi.h"
#include "../../c/checkpoint/checkpoint.h"

_Static_assert((int)CHECKPOINT_RESTART_COMMITTED == HARNESS_RESTART_COMMITTED,
    "checkpoint_restart_status_t::CHECKPOINT_RESTART_COMMITTED must match HARNESS_RESTART_COMMITTED");
_Static_assert((int)CHECKPOINT_RESTART_RESTORED == HARNESS_RESTART_RESTORED,
    "checkpoint_restart_status_t::CHECKPOINT_RESTART_RESTORED must match HARNESS_RESTART_RESTORED");
_Static_assert((int)CHECKPOINT_RESTART_RESTORE_FAILED == HARNESS_RESTART_RESTORE_FAILED,
    "checkpoint_restart_status_t::CHECKPOINT_RESTART_RESTORE_FAILED must match HARNESS_RESTART_RESTORE_FAILED");

volatile uint32_t harness_iteration;
volatile uint32_t harness_stage;
volatile uint32_t harness_fault_target;
volatile uint32_t harness_fault_value;
volatile uint32_t harness_last_expected;
volatile uint32_t harness_last_initial_value;
volatile uint32_t harness_last_value;
volatile uint32_t harness_last_status;
volatile uint32_t harness_last_restart_status;
volatile uint32_t harness_last_active_check;
volatile uint32_t harness_last_checkpoint_check;
volatile uint32_t harness_last_active_value;
volatile uint32_t harness_last_checkpoint_value;
volatile uint32_t harness_passes;
volatile uint32_t harness_failures;
volatile uint32_t harness_last_fault_target;
volatile checkpoint_record_t harness_c_checkpoint_state;

static uint32_t sample_initial_value(uint32_t iteration) {
    return 100u + ((iteration * 37u) % 700u);
}

static uint32_t sample_updated_value(uint32_t iteration) {
    return 100u + ((iteration * 53u + 211u) % 700u);
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
void harness_injection_point_after_mutation(void) {
    __asm__ volatile("nop");
}

__attribute__((used, noinline))
void harness_injection_point_after_commit(void) {
    __asm__ volatile("nop");
}

static void mirror_state(void) {
    const checkpoint_record_t *state =
        (const checkpoint_record_t *)&harness_c_checkpoint_state;
    harness_last_active_value = state->active.value;
    harness_last_checkpoint_value = state->checkpoint.value;
}

static void apply_pending_fault(void) {
    const uint32_t target = harness_fault_target;
    const uint32_t value = harness_fault_value;
    checkpoint_record_t *state = (checkpoint_record_t *)&harness_c_checkpoint_state;

    harness_last_fault_target = target;

    switch (target) {
    case HARNESS_FAULT_ACTIVE_VALUE:
        state->active.value = value;
        break;
    case HARNESS_FAULT_ACTIVE_LENGTH:
        state->active.length = value;
        break;
    case HARNESS_FAULT_ACTIVE_CHECKSUM:
        state->active.checksum ^= value;
        break;
    case HARNESS_FAULT_CHECKPOINT_VALUE:
        state->checkpoint.value = value;
        break;
    case HARNESS_FAULT_CHECKPOINT_CHECKSUM:
        state->checkpoint.checksum ^= value;
        break;
    case HARNESS_FAULT_ACTIVE_VALUE_AND_CHECKPOINT_CHECKSUM:
        state->active.value = value;
        state->checkpoint.checksum ^= 0x10u;
        break;
    default:
        break;
    }

    harness_fault_target = HARNESS_FAULT_NONE;
    mirror_state();
}

static void validate(uint32_t initial, uint32_t expected) {
    const uint32_t target = harness_last_fault_target;
    const uint32_t restart = harness_last_restart_status;
    const uint32_t active_check = harness_last_active_check;
    const uint32_t checkpoint_check = harness_last_checkpoint_check;
    const uint32_t active_value = harness_last_active_value;
    const uint32_t checkpoint_value = harness_last_checkpoint_value;

    switch (target) {
    case HARNESS_FAULT_ACTIVE_VALUE:
        if (restart == HARNESS_RESTART_RESTORED &&
            active_check == CHECKER_ERR_ABOVE_MAX &&
            checkpoint_check == CHECKER_OK &&
            active_value == initial &&
            checkpoint_value == initial) {
            harness_passes += 1;
        } else {
            harness_failures += 1;
        }
        return;
    case HARNESS_FAULT_ACTIVE_LENGTH:
        if (restart == HARNESS_RESTART_RESTORED &&
            active_check == CHECKER_ERR_INVALID_LENGTH &&
            checkpoint_check == CHECKER_OK &&
            active_value == initial &&
            checkpoint_value == initial) {
            harness_passes += 1;
        } else {
            harness_failures += 1;
        }
        return;
    case HARNESS_FAULT_ACTIVE_CHECKSUM:
        if (restart == HARNESS_RESTART_RESTORED &&
            active_check == CHECKER_ERR_INVALID_CHECKSUM &&
            checkpoint_check == CHECKER_OK &&
            active_value == initial &&
            checkpoint_value == initial) {
            harness_passes += 1;
        } else {
            harness_failures += 1;
        }
        return;
    case HARNESS_FAULT_ACTIVE_VALUE_AND_CHECKPOINT_CHECKSUM:
        if (restart == HARNESS_RESTART_RESTORE_FAILED &&
            active_check == CHECKER_ERR_ABOVE_MAX &&
            checkpoint_check == CHECKER_ERR_INVALID_CHECKSUM &&
            active_value == harness_fault_value) {
            harness_passes += 1;
        } else {
            harness_failures += 1;
        }
        return;
    default:
        if (restart == HARNESS_RESTART_COMMITTED &&
            active_check == CHECKER_OK &&
            checkpoint_check == CHECKER_OK &&
            active_value == expected &&
            checkpoint_value == expected) {
            harness_passes += 1;
        } else {
            harness_failures += 1;
        }
        return;
    }
}

void harness_main(void) {
    harness_stage = HARNESS_STAGE_BOOT;

    for (;;) {
        const uint32_t iteration = harness_iteration + 1u;
        const uint32_t initial = sample_initial_value(iteration);
        const uint32_t expected = sample_updated_value(iteration);
        const checker_record_t record = sample_record(initial);
        checkpoint_restart_result_t result;

        harness_iteration = iteration;
        harness_last_initial_value = initial;
        harness_last_expected = expected;
        harness_last_value = 0u;
        harness_last_status = HARNESS_STATUS_OK;
        harness_last_restart_status = HARNESS_RESTART_COMMITTED;
        harness_last_active_check = CHECKER_OK;
        harness_last_checkpoint_check = CHECKER_OK;
        harness_last_fault_target = HARNESS_FAULT_NONE;
        harness_c_checkpoint_state = checkpoint_record_init(record);

        harness_stage = HARNESS_STAGE_AFTER_CHECKPOINT;
        checkpoint_record_capture((checkpoint_record_t *)&harness_c_checkpoint_state);

        ((checkpoint_record_t *)&harness_c_checkpoint_state)->active.value = expected;
        checker_record_refresh_checksum(
            &((checkpoint_record_t *)&harness_c_checkpoint_state)->active);
        mirror_state();

        harness_stage = HARNESS_STAGE_AFTER_MUTATION;
        harness_injection_point_after_mutation();

        apply_pending_fault();

        harness_stage = HARNESS_STAGE_BEFORE_COMMIT;
        result = checkpoint_record_commit_or_restart(
            (checkpoint_record_t *)&harness_c_checkpoint_state);

        harness_last_restart_status = result.status;
        harness_last_active_check = result.active_check;
        harness_last_checkpoint_check = result.checkpoint_check;
        mirror_state();
        harness_last_value = harness_last_active_value;

        harness_stage = HARNESS_STAGE_AFTER_COMMIT;
        validate(initial, expected);
        harness_injection_point_after_commit();
    }
}

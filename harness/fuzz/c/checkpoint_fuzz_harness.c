#include <stdint.h>

#include "fuzz_common.h"
#include "../../common/harness_abi.h"
#include "../../../c/checkpoint/checkpoint.h"

_Static_assert((int)CHECKPOINT_RESTART_COMMITTED == HARNESS_RESTART_COMMITTED,
    "checkpoint_restart_status_t::CHECKPOINT_RESTART_COMMITTED must match HARNESS_RESTART_COMMITTED");
_Static_assert((int)CHECKPOINT_RESTART_RESTORED == HARNESS_RESTART_RESTORED,
    "checkpoint_restart_status_t::CHECKPOINT_RESTART_RESTORED must match HARNESS_RESTART_RESTORED");
_Static_assert((int)CHECKPOINT_RESTART_RESTORE_FAILED == HARNESS_RESTART_RESTORE_FAILED,
    "checkpoint_restart_status_t::CHECKPOINT_RESTART_RESTORE_FAILED must match HARNESS_RESTART_RESTORE_FAILED");

volatile checkpoint_record_t harness_fuzz_checkpoint_state;

static uint32_t sample_initial_value(uint64_t *rng) {
    return 100u + (harness_random_u32(rng) % 700u);
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

void harness_main(void) {
    uint64_t rng = harness_seed_state();
    const uint32_t initial = sample_initial_value(&rng);
    const uint32_t expected = sample_initial_value(&rng);
    checkpoint_restart_result_t result;

    harness_expected = expected;
    harness_fuzz_checkpoint_state = checkpoint_record_init(sample_record(initial));
    (void)checkpoint_record_capture((checkpoint_record_t *)&harness_fuzz_checkpoint_state);
    ((checkpoint_record_t *)&harness_fuzz_checkpoint_state)->active.value = expected;
    checker_record_refresh_checksum(
        &((checkpoint_record_t *)&harness_fuzz_checkpoint_state)->active);

    harness_open_fault_window();
    result = checkpoint_record_commit_or_restart(
        (checkpoint_record_t *)&harness_fuzz_checkpoint_state);
    harness_close_fault_window();

    harness_output = harness_fuzz_checkpoint_state.active.value;
    harness_error_code = (uint32_t)result.status;
    if (result.status != CHECKPOINT_RESTART_COMMITTED ||
        result.active_check != CHECKER_OK ||
        result.checkpoint_check != CHECKER_OK) {
        harness_detected = 1u;
    }
    if (harness_detected != 0u && harness_output == harness_expected) {
        harness_corrected = 1u;
    }
    if (result.status != CHECKPOINT_RESTART_COMMITTED &&
        harness_output != harness_expected) {
        harness_safe_state = 1u;
    }

    harness_finish();
}

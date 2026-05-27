#include <stdint.h>

#include "fuzz_common.h"
#include "../../common/harness_abi.h"
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

volatile checkpoint_record_t harness_fuzz_recovery_block_state;

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
    const uint32_t sample = harness_random_u32(&rng);
    const uint32_t initial = sample_initial_value(&rng);
    const uint32_t expected = recovery_block_sample_primary_value(sample);
    recovery_block_sample_update_t update = {
        sample,
        RECOVERY_BLOCK_SAMPLE_FAULT_NONE,
    };
    recovery_block_result_t result;

    harness_expected = expected;
    harness_fuzz_recovery_block_state = checkpoint_record_init(sample_record(initial));

    harness_open_fault_window();
    result = recovery_block_run(
        (checkpoint_record_t *)&harness_fuzz_recovery_block_state,
        recovery_block_sample_primary,
        recovery_block_sample_alternate,
        &update);
    harness_close_fault_window();

    harness_output = harness_fuzz_recovery_block_state.active.value;
    harness_error_code = (uint32_t)result.status;
    if (result.status != RECOVERY_BLOCK_PRIMARY_ACCEPTED ||
        result.checkpoint_check != CHECKER_OK ||
        result.primary_check != CHECKER_OK ||
        result.restore_check != CHECKER_OK ||
        result.alternate_check != CHECKER_OK) {
        harness_detected = 1u;
    }
    if (harness_detected != 0u && harness_output == harness_expected) {
        harness_corrected = 1u;
    }
    if (result.status == RECOVERY_BLOCK_UNRECOVERABLE ||
        result.status == RECOVERY_BLOCK_CHECKPOINT_FAILED ||
        result.status == RECOVERY_BLOCK_RESTORE_FAILED) {
        harness_safe_state = 1u;
    }

    harness_finish();
}

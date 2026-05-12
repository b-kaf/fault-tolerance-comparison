#include <stdint.h>

#include "recovery_block.h"
#include "test.h"

static checker_record_t clean_record(void) {
    return checker_record_init(CHECKER_TAG_SAMPLE, 50, 0, 1000, 6, 16);
}

static void test_status_codes_are_stable_abi_values(void) {
    printf("Recovery block: status codes are stable ABI values\n");
    CHECK(recovery_block_status_code(RECOVERY_BLOCK_PRIMARY_ACCEPTED) == 0);
    CHECK(recovery_block_status_code(RECOVERY_BLOCK_ALTERNATE_ACCEPTED) == 1);
    CHECK(recovery_block_status_code(RECOVERY_BLOCK_UNRECOVERABLE) == 2);
    CHECK(recovery_block_status_code(RECOVERY_BLOCK_CHECKPOINT_FAILED) == 3);
    CHECK(recovery_block_status_code(RECOVERY_BLOCK_RESTORE_FAILED) == 4);
}

static void test_probe_variants_compute_same_accepted_value(void) {
    printf("Recovery block: probe variants compute same accepted value\n");
    for (uint32_t sample = 0; sample < 2000; sample += 137) {
        CHECK(recovery_block_probe_primary_value(sample) ==
              recovery_block_probe_alternate_value(sample));
    }
}

static void test_primary_success_commits_primary_result(void) {
    printf("Recovery block: primary success commits primary result\n");
    checkpoint_record_t state = checkpoint_record_init(clean_record());
    const recovery_block_probe_update_t update = {
        7,
        RECOVERY_BLOCK_PROBE_FAULT_NONE,
    };
    const uint32_t expected = recovery_block_probe_primary_value(update.sample);

    const recovery_block_result_t result =
        recovery_block_probe_update(&state, update);

    CHECK(result.status == RECOVERY_BLOCK_PRIMARY_ACCEPTED);
    CHECK(result.checkpoint_check == CHECKER_OK);
    CHECK(result.primary_check == CHECKER_OK);
    CHECK(result.restore_check == CHECKER_OK);
    CHECK(result.alternate_check == CHECKER_OK);
    CHECK(state.active.value == expected);
    CHECK(state.checkpoint.value == expected);
    CHECK(checker_record_validate(&state.active) == CHECKER_OK);
    CHECK(checker_record_validate(&state.checkpoint) == CHECKER_OK);
}

static void test_primary_range_failure_recovers_with_alternate(void) {
    printf("Recovery block: primary range failure recovers with alternate\n");
    checkpoint_record_t state = checkpoint_record_init(clean_record());
    const recovery_block_probe_update_t update = {
        11,
        RECOVERY_BLOCK_PROBE_FAULT_PRIMARY_RANGE,
    };
    const uint32_t expected = recovery_block_probe_alternate_value(update.sample);

    const recovery_block_result_t result =
        recovery_block_probe_update(&state, update);

    CHECK(result.status == RECOVERY_BLOCK_ALTERNATE_ACCEPTED);
    CHECK(result.checkpoint_check == CHECKER_OK);
    CHECK(result.primary_check == CHECKER_ERR_ABOVE_MAX);
    CHECK(result.restore_check == CHECKER_OK);
    CHECK(result.alternate_check == CHECKER_OK);
    CHECK(state.active.value == expected);
    CHECK(state.checkpoint.value == expected);
    CHECK(checker_record_validate(&state.active) == CHECKER_OK);
}

static void test_primary_checksum_failure_recovers_with_alternate(void) {
    printf("Recovery block: primary checksum failure recovers with alternate\n");
    checkpoint_record_t state = checkpoint_record_init(clean_record());
    const recovery_block_probe_update_t update = {
        13,
        RECOVERY_BLOCK_PROBE_FAULT_PRIMARY_CHECKSUM,
    };
    const uint32_t expected = recovery_block_probe_alternate_value(update.sample);

    const recovery_block_result_t result =
        recovery_block_probe_update(&state, update);

    CHECK(result.status == RECOVERY_BLOCK_ALTERNATE_ACCEPTED);
    CHECK(result.primary_check == CHECKER_ERR_INVALID_CHECKSUM);
    CHECK(result.restore_check == CHECKER_OK);
    CHECK(result.alternate_check == CHECKER_OK);
    CHECK(state.active.value == expected);
    CHECK(state.checkpoint.value == expected);
}

static void test_alternate_failure_is_unrecoverable_and_restores_checkpoint(void) {
    printf("Recovery block: alternate failure is unrecoverable and restores checkpoint\n");
    checkpoint_record_t state = checkpoint_record_init(clean_record());
    const recovery_block_probe_update_t update = {
        17,
        RECOVERY_BLOCK_PROBE_FAULT_PRIMARY_RANGE |
            RECOVERY_BLOCK_PROBE_FAULT_ALTERNATE_CHECKSUM,
    };

    const recovery_block_result_t result =
        recovery_block_probe_update(&state, update);

    CHECK(result.status == RECOVERY_BLOCK_UNRECOVERABLE);
    CHECK(result.primary_check == CHECKER_ERR_ABOVE_MAX);
    CHECK(result.restore_check == CHECKER_OK);
    CHECK(result.alternate_check == CHECKER_ERR_INVALID_CHECKSUM);
    CHECK(state.active.value == 50);
    CHECK(state.checkpoint.value == 50);
    CHECK(checker_record_validate(&state.active) == CHECKER_OK);
}

static void test_invalid_entry_state_fails_before_primary_runs(void) {
    printf("Recovery block: invalid entry state fails before primary runs\n");
    checkpoint_record_t state = checkpoint_record_init(clean_record());
    state.active.length = 20;
    const recovery_block_probe_update_t update = {
        19,
        RECOVERY_BLOCK_PROBE_FAULT_NONE,
    };

    const recovery_block_result_t result =
        recovery_block_probe_update(&state, update);

    CHECK(result.status == RECOVERY_BLOCK_CHECKPOINT_FAILED);
    CHECK(result.checkpoint_check == CHECKER_ERR_INVALID_LENGTH);
    CHECK(result.primary_check == CHECKER_OK);
    CHECK(result.alternate_check == CHECKER_OK);
    CHECK(state.active.length == 20);
    CHECK(state.checkpoint.length == 6);
}

static void fail_primary_range(checker_record_t *active, void *context) {
    (void)context;
    active->value = active->max + 1u;
    checker_record_refresh_checksum(active);
}

static void valid_alternate_value(checker_record_t *active, void *context) {
    const uint32_t *value = (const uint32_t *)context;
    active->value = *value;
    checker_record_refresh_checksum(active);
}

static void corrupt_checkpoint_checksum(checkpoint_record_t *state, void *context) {
    (void)context;
    state->checkpoint.checksum ^= 0x10u;
}

static void test_corrupted_checkpoint_reports_restore_failure(void) {
    printf("Recovery block: corrupted checkpoint reports restore failure\n");
    checkpoint_record_t state = checkpoint_record_init(clean_record());
    const uint32_t expected = 123u;

    const recovery_block_result_t result = recovery_block_run_with_hooks(
        &state,
        fail_primary_range,
        corrupt_checkpoint_checksum,
        valid_alternate_value,
        0,
        (void *)&expected);

    CHECK(result.status == RECOVERY_BLOCK_RESTORE_FAILED);
    CHECK(result.primary_check == CHECKER_ERR_ABOVE_MAX);
    CHECK(result.restore_check == CHECKER_ERR_INVALID_CHECKSUM);
    CHECK(result.alternate_check == CHECKER_OK);
    CHECK(state.active.value == 1001u);
}

int main(void) {
    test_status_codes_are_stable_abi_values();
    test_probe_variants_compute_same_accepted_value();
    test_primary_success_commits_primary_result();
    test_primary_range_failure_recovers_with_alternate();
    test_primary_checksum_failure_recovers_with_alternate();
    test_alternate_failure_is_unrecoverable_and_restores_checkpoint();
    test_invalid_entry_state_fails_before_primary_runs();
    test_corrupted_checkpoint_reports_restore_failure();

    return test_finish("recovery block");
}

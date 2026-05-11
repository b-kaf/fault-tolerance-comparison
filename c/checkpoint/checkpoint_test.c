#include <stdint.h>

#include "checkpoint.h"
#include "test.h"

static checker_record_t clean_record(void) {
    return checker_record_init(CHECKER_TAG_SAMPLE, 50, 10, 100, 3, 8);
}

static void test_restart_status_codes_are_stable_abi_values(void) {
    printf("Checkpoint: restart status codes are stable ABI values\n");
    CHECK(checkpoint_restart_status_code(CHECKPOINT_RESTART_COMMITTED) == 0);
    CHECK(checkpoint_restart_status_code(CHECKPOINT_RESTART_RESTORED) == 1);
    CHECK(checkpoint_restart_status_code(CHECKPOINT_RESTART_RESTORE_FAILED) == 2);
}

static void test_init_mirrors_initial_state_into_active_and_checkpoint(void) {
    printf("Checkpoint: init mirrors initial state into active and checkpoint\n");
    const checkpoint_record_t state = checkpoint_record_init(clean_record());

    CHECK(state.active.value == 50);
    CHECK(state.checkpoint.value == 50);
    CHECK(checker_record_validate(&state.active) == CHECKER_OK);
    CHECK(checker_record_validate(&state.checkpoint) == CHECKER_OK);
}

static void test_capture_valid_active_state_updates_checkpoint(void) {
    printf("Checkpoint: capture valid active state updates checkpoint\n");
    checkpoint_record_t state = checkpoint_record_init(clean_record());

    state.active.value = 60;
    checker_record_refresh_checksum(&state.active);

    CHECK(checkpoint_record_capture(&state) == CHECKER_OK);
    CHECK(state.checkpoint.value == 60);
    CHECK(checker_record_validate(&state.checkpoint) == CHECKER_OK);
}

static void test_capture_rejects_invalid_active_state_and_preserves_checkpoint(void) {
    printf("Checkpoint: capture rejects invalid active state and preserves checkpoint\n");
    checkpoint_record_t state = checkpoint_record_init(clean_record());

    state.active.value = 101;

    CHECK(checkpoint_record_capture(&state) == CHECKER_ERR_ABOVE_MAX);
    CHECK(state.checkpoint.value == 50);
    CHECK(checker_record_validate(&state.checkpoint) == CHECKER_OK);
}

static void test_restore_replaces_corrupted_active_state_from_valid_checkpoint(void) {
    printf("Checkpoint: restore replaces corrupted active state from valid checkpoint\n");
    checkpoint_record_t state = checkpoint_record_init(clean_record());

    state.active.value = 101;

    CHECK(checkpoint_record_restore(&state) == CHECKER_OK);
    CHECK(state.active.value == 50);
    CHECK(checker_record_validate(&state.active) == CHECKER_OK);
}

static void test_commit_accepts_valid_active_state_and_advances_checkpoint(void) {
    printf("Checkpoint: commit accepts valid active state and advances checkpoint\n");
    checkpoint_record_t state = checkpoint_record_init(clean_record());

    state.active.value = 60;
    checker_record_refresh_checksum(&state.active);
    const checkpoint_restart_result_t result =
        checkpoint_record_commit_or_restart(&state);

    CHECK(result.status == CHECKPOINT_RESTART_COMMITTED);
    CHECK(result.active_check == CHECKER_OK);
    CHECK(result.checkpoint_check == CHECKER_OK);
    CHECK(state.active.value == 60);
    CHECK(state.checkpoint.value == 60);
}

static void test_commit_restarts_invalid_active_state_from_checkpoint(void) {
    printf("Checkpoint: commit restarts invalid active state from checkpoint\n");
    checkpoint_record_t state = checkpoint_record_init(clean_record());

    state.active.length = 9;
    const checkpoint_restart_result_t result =
        checkpoint_record_commit_or_restart(&state);

    CHECK(result.status == CHECKPOINT_RESTART_RESTORED);
    CHECK(result.active_check == CHECKER_ERR_INVALID_LENGTH);
    CHECK(result.checkpoint_check == CHECKER_OK);
    CHECK(state.active.length == 3);
    CHECK(checker_record_validate(&state.active) == CHECKER_OK);
}

static void test_commit_reports_restore_failure_when_checkpoint_is_invalid(void) {
    printf("Checkpoint: commit reports restore failure when checkpoint is invalid\n");
    checkpoint_record_t state = checkpoint_record_init(clean_record());

    state.active.value = 101;
    state.checkpoint.checksum ^= 0x10;
    const checkpoint_restart_result_t result =
        checkpoint_record_commit_or_restart(&state);

    CHECK(result.status == CHECKPOINT_RESTART_RESTORE_FAILED);
    CHECK(result.active_check == CHECKER_ERR_ABOVE_MAX);
    CHECK(result.checkpoint_check == CHECKER_ERR_INVALID_CHECKSUM);
    CHECK(state.active.value == 101);
}

int main(void) {
    test_restart_status_codes_are_stable_abi_values();
    test_init_mirrors_initial_state_into_active_and_checkpoint();
    test_capture_valid_active_state_updates_checkpoint();
    test_capture_rejects_invalid_active_state_and_preserves_checkpoint();
    test_restore_replaces_corrupted_active_state_from_valid_checkpoint();
    test_commit_accepts_valid_active_state_and_advances_checkpoint();
    test_commit_restarts_invalid_active_state_from_checkpoint();
    test_commit_reports_restore_failure_when_checkpoint_is_invalid();

    return test_finish("checkpoint");
}

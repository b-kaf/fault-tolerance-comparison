#include <stdint.h>

#include "control_flow.h"
#include "test.h"

static void test_status_codes_are_stable_abi_values(void) {
    printf("Control flow: status codes are stable ABI values\n");
    CHECK(control_flow_status_code(CONTROL_FLOW_OK) == 0);
    CHECK(control_flow_status_code(CONTROL_FLOW_ERR_INVALID_TRANSITION) == 1);
    CHECK(control_flow_status_code(CONTROL_FLOW_ERR_BAD_SIGNATURE) == 2);
    CHECK(control_flow_status_code(CONTROL_FLOW_ERR_UNEXPECTED_TERMINAL) == 3);
}

static void test_phase_codes_are_stable_abi_values(void) {
    printf("Control flow: phase codes are stable ABI values\n");
    CHECK(control_flow_phase_code(CONTROL_FLOW_PHASE_START) == 0);
    CHECK(control_flow_phase_code(CONTROL_FLOW_PHASE_READ_INPUT) == 1);
    CHECK(control_flow_phase_code(CONTROL_FLOW_PHASE_COMPUTE) == 2);
    CHECK(control_flow_phase_code(CONTROL_FLOW_PHASE_VALIDATE) == 3);
    CHECK(control_flow_phase_code(CONTROL_FLOW_PHASE_COMMIT) == 4);
    CHECK(control_flow_phase_code(CONTROL_FLOW_PHASE_DONE) == 5);
}

static void test_legal_sequence_reaches_done(void) {
    printf("Control flow: legal sequence reaches done\n");
    control_flow_monitor_t monitor = control_flow_monitor_init();

    CHECK(control_flow_monitor_advance(
        &monitor,
        CONTROL_FLOW_PHASE_START,
        CONTROL_FLOW_PHASE_READ_INPUT) == CONTROL_FLOW_OK);
    CHECK(control_flow_monitor_advance(
        &monitor,
        CONTROL_FLOW_PHASE_READ_INPUT,
        CONTROL_FLOW_PHASE_COMPUTE) == CONTROL_FLOW_OK);
    CHECK(control_flow_monitor_advance(
        &monitor,
        CONTROL_FLOW_PHASE_COMPUTE,
        CONTROL_FLOW_PHASE_VALIDATE) == CONTROL_FLOW_OK);
    CHECK(control_flow_monitor_advance(
        &monitor,
        CONTROL_FLOW_PHASE_VALIDATE,
        CONTROL_FLOW_PHASE_COMMIT) == CONTROL_FLOW_OK);
    CHECK(control_flow_monitor_advance(
        &monitor,
        CONTROL_FLOW_PHASE_COMMIT,
        CONTROL_FLOW_PHASE_DONE) == CONTROL_FLOW_OK);

    CHECK(control_flow_monitor_finish(&monitor) == CONTROL_FLOW_OK);
    CHECK(monitor.phase == CONTROL_FLOW_PHASE_DONE);
    CHECK(monitor.transitions == 5u);
}

static void test_corrupted_phase_is_invalid_transition(void) {
    printf("Control flow: corrupted phase is invalid transition\n");
    control_flow_monitor_t monitor = control_flow_monitor_init();

    CHECK(control_flow_monitor_advance(
        &monitor,
        CONTROL_FLOW_PHASE_START,
        CONTROL_FLOW_PHASE_READ_INPUT) == CONTROL_FLOW_OK);

    monitor.phase = CONTROL_FLOW_PHASE_COMMIT;

    CHECK(control_flow_monitor_advance(
        &monitor,
        CONTROL_FLOW_PHASE_READ_INPUT,
        CONTROL_FLOW_PHASE_COMPUTE) == CONTROL_FLOW_ERR_INVALID_TRANSITION);
}

static void test_corrupted_signature_is_bad_signature(void) {
    printf("Control flow: corrupted signature is bad signature\n");
    control_flow_monitor_t monitor = control_flow_monitor_init();

    monitor.signature ^= 0x10u;

    CHECK(control_flow_monitor_advance(
        &monitor,
        CONTROL_FLOW_PHASE_START,
        CONTROL_FLOW_PHASE_READ_INPUT) == CONTROL_FLOW_ERR_BAD_SIGNATURE);
}

static void test_skipped_phase_is_invalid_transition(void) {
    printf("Control flow: skipped phase is invalid transition\n");
    control_flow_monitor_t monitor = control_flow_monitor_init();

    CHECK(control_flow_monitor_advance(
        &monitor,
        CONTROL_FLOW_PHASE_START,
        CONTROL_FLOW_PHASE_READ_INPUT) == CONTROL_FLOW_OK);
    CHECK(control_flow_monitor_advance(
        &monitor,
        CONTROL_FLOW_PHASE_COMPUTE,
        CONTROL_FLOW_PHASE_VALIDATE) == CONTROL_FLOW_ERR_INVALID_TRANSITION);
}

static void test_repeated_phase_is_invalid_transition(void) {
    printf("Control flow: repeated phase is invalid transition\n");
    control_flow_monitor_t monitor = control_flow_monitor_init();

    CHECK(control_flow_monitor_advance(
        &monitor,
        CONTROL_FLOW_PHASE_START,
        CONTROL_FLOW_PHASE_READ_INPUT) == CONTROL_FLOW_OK);
    CHECK(control_flow_monitor_advance(
        &monitor,
        CONTROL_FLOW_PHASE_START,
        CONTROL_FLOW_PHASE_READ_INPUT) == CONTROL_FLOW_ERR_INVALID_TRANSITION);
}

static void test_unexpected_terminal_and_done_signature_corruption(void) {
    printf("Control flow: unexpected terminal and done signature corruption\n");
    control_flow_monitor_t monitor = control_flow_monitor_init();

    CHECK(control_flow_monitor_advance(
        &monitor,
        CONTROL_FLOW_PHASE_START,
        CONTROL_FLOW_PHASE_READ_INPUT) == CONTROL_FLOW_OK);
    CHECK(control_flow_monitor_finish(&monitor) ==
          CONTROL_FLOW_ERR_UNEXPECTED_TERMINAL);

    monitor.phase = CONTROL_FLOW_PHASE_DONE;
    monitor.signature = control_flow_phase_signature(CONTROL_FLOW_PHASE_START);
    CHECK(control_flow_monitor_finish(&monitor) ==
          CONTROL_FLOW_ERR_BAD_SIGNATURE);
}

int main(void) {
    test_status_codes_are_stable_abi_values();
    test_phase_codes_are_stable_abi_values();
    test_legal_sequence_reaches_done();
    test_corrupted_phase_is_invalid_transition();
    test_corrupted_signature_is_bad_signature();
    test_skipped_phase_is_invalid_transition();
    test_repeated_phase_is_invalid_transition();
    test_unexpected_terminal_and_done_signature_corruption();

    return test_finish("control flow");
}

#include <stdint.h>

#include "fuzz_common.h"
#include "../../common/harness_abi.h"
#include "../../../c/control_flow/control_flow.h"

_Static_assert((int)CONTROL_FLOW_OK == HARNESS_CONTROL_OK,
    "control_flow_status_t::CONTROL_FLOW_OK must match HARNESS_CONTROL_OK");
_Static_assert((int)CONTROL_FLOW_ERR_INVALID_TRANSITION == HARNESS_CONTROL_INVALID_TRANSITION,
    "control_flow_status_t::CONTROL_FLOW_ERR_INVALID_TRANSITION must match HARNESS_CONTROL_INVALID_TRANSITION");
_Static_assert((int)CONTROL_FLOW_ERR_BAD_SIGNATURE == HARNESS_CONTROL_BAD_SIGNATURE,
    "control_flow_status_t::CONTROL_FLOW_ERR_BAD_SIGNATURE must match HARNESS_CONTROL_BAD_SIGNATURE");
_Static_assert((int)CONTROL_FLOW_ERR_UNEXPECTED_TERMINAL == HARNESS_CONTROL_UNEXPECTED_TERMINAL,
    "control_flow_status_t::CONTROL_FLOW_ERR_UNEXPECTED_TERMINAL must match HARNESS_CONTROL_UNEXPECTED_TERMINAL");

volatile control_flow_monitor_t harness_fuzz_control_flow_monitor;

static uint32_t sample_input(uint64_t *rng) {
    return 100u + (harness_random_u32(rng) % 900u);
}

static uint32_t compute_value(uint32_t input) {
    return input + 7u;
}

static control_flow_status_t record_status(control_flow_status_t status) {
    if (!control_flow_passed(status)) {
        harness_detected = 1u;
        harness_error_code = (uint32_t)status;
    }
    return status;
}

static void run_control_flow(uint32_t input) {
    control_flow_monitor_t *monitor =
        (control_flow_monitor_t *)&harness_fuzz_control_flow_monitor;
    uint32_t computed = 0u;
    control_flow_status_t status;

    status = control_flow_monitor_advance(
        monitor,
        CONTROL_FLOW_PHASE_START,
        CONTROL_FLOW_PHASE_READ_INPUT);
    if (!control_flow_passed(record_status(status))) {
        harness_safe_state = 1u;
        return;
    }

    status = control_flow_monitor_advance(
        monitor,
        CONTROL_FLOW_PHASE_READ_INPUT,
        CONTROL_FLOW_PHASE_COMPUTE);
    if (!control_flow_passed(record_status(status))) {
        harness_safe_state = 1u;
        return;
    }

    computed = compute_value(input);

    status = control_flow_monitor_advance(
        monitor,
        CONTROL_FLOW_PHASE_COMPUTE,
        CONTROL_FLOW_PHASE_VALIDATE);
    if (!control_flow_passed(record_status(status))) {
        harness_safe_state = 1u;
        return;
    }

    status = control_flow_monitor_advance(
        monitor,
        CONTROL_FLOW_PHASE_VALIDATE,
        CONTROL_FLOW_PHASE_COMMIT);
    if (!control_flow_passed(record_status(status))) {
        harness_safe_state = 1u;
        return;
    }

    harness_output = computed;

    status = control_flow_monitor_advance(
        monitor,
        CONTROL_FLOW_PHASE_COMMIT,
        CONTROL_FLOW_PHASE_DONE);
    if (!control_flow_passed(record_status(status))) {
        return;
    }

    status = control_flow_monitor_finish(monitor);
    (void)record_status(status);
}

void harness_main(void) {
    uint64_t rng = harness_seed_state();
    const uint32_t input = sample_input(&rng);
    const uint32_t expected = compute_value(input);

    harness_expected = expected;
    harness_fuzz_control_flow_monitor = control_flow_monitor_init();

    harness_open_fault_window();
    run_control_flow(input);
    harness_close_fault_window();

    if (harness_detected != 0u && harness_output == harness_expected) {
        harness_corrected = 1u;
    }

    harness_finish();
}

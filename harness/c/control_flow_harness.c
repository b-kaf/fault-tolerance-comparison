#include <stdint.h>

#include "harness_abi.h"
#include "../../c/control_flow/control_flow.h"

_Static_assert((int)CONTROL_FLOW_OK == HARNESS_CONTROL_OK,
    "control_flow_status_t::CONTROL_FLOW_OK must match HARNESS_CONTROL_OK");
_Static_assert((int)CONTROL_FLOW_ERR_INVALID_TRANSITION == HARNESS_CONTROL_INVALID_TRANSITION,
    "control_flow_status_t::CONTROL_FLOW_ERR_INVALID_TRANSITION must match HARNESS_CONTROL_INVALID_TRANSITION");
_Static_assert((int)CONTROL_FLOW_ERR_BAD_SIGNATURE == HARNESS_CONTROL_BAD_SIGNATURE,
    "control_flow_status_t::CONTROL_FLOW_ERR_BAD_SIGNATURE must match HARNESS_CONTROL_BAD_SIGNATURE");
_Static_assert((int)CONTROL_FLOW_ERR_UNEXPECTED_TERMINAL == HARNESS_CONTROL_UNEXPECTED_TERMINAL,
    "control_flow_status_t::CONTROL_FLOW_ERR_UNEXPECTED_TERMINAL must match HARNESS_CONTROL_UNEXPECTED_TERMINAL");

volatile uint32_t harness_iteration;
volatile uint32_t harness_stage;
volatile uint32_t harness_fault_target;
volatile uint32_t harness_fault_value;
volatile uint32_t harness_last_expected;
volatile uint32_t harness_last_value;
volatile uint32_t harness_last_status;
volatile uint32_t harness_last_control_status;
volatile uint32_t harness_last_terminal_status;
volatile uint32_t harness_last_phase;
volatile uint32_t harness_last_signature;
volatile uint32_t harness_last_transitions;
volatile uint32_t harness_passes;
volatile uint32_t harness_failures;
volatile uint32_t harness_last_fault_target;
volatile control_flow_monitor_t harness_c_control_flow_monitor;

static uint32_t pattern(uint32_t iteration) {
    return 100u + ((iteration * 41u) % 900u);
}

static uint32_t compute_value(uint32_t input) {
    return input + 7u;
}

__attribute__((used, noinline))
void harness_injection_point_before_control_flow(void) {
    __asm__ volatile("nop");
}

__attribute__((used, noinline))
void harness_injection_point_after_control_flow(void) {
    __asm__ volatile("nop");
}

static void mirror_monitor(const control_flow_monitor_t *monitor) {
    harness_last_phase = monitor->phase;
    harness_last_signature = monitor->signature;
    harness_last_transitions = monitor->transitions;
    harness_c_control_flow_monitor = *monitor;
}

static void apply_after_read_fault(control_flow_monitor_t *monitor) {
    switch (harness_fault_target) {
    case HARNESS_FAULT_CONTROL_PHASE:
        monitor->phase = harness_fault_value;
        break;
    case HARNESS_FAULT_CONTROL_SIGNATURE:
        monitor->signature ^= harness_fault_value;
        break;
    default:
        break;
    }
    mirror_monitor(monitor);
}

static control_flow_status_t record_status(control_flow_status_t status) {
    harness_last_control_status = status;
    if (!control_flow_passed(status)) {
        harness_last_status = status;
    }
    return status;
}

static void run_control_flow(uint32_t input) {
    control_flow_monitor_t monitor = control_flow_monitor_init();
    uint32_t computed = 0u;
    control_flow_status_t status = CONTROL_FLOW_OK;

    mirror_monitor(&monitor);

    status = control_flow_monitor_advance(
        &monitor,
        CONTROL_FLOW_PHASE_START,
        CONTROL_FLOW_PHASE_READ_INPUT);
    if (!control_flow_passed(record_status(status))) {
        mirror_monitor(&monitor);
        return;
    }

    harness_stage = HARNESS_STAGE_AFTER_CONTROL_READ;
    apply_after_read_fault(&monitor);

    if (harness_fault_target == HARNESS_FAULT_CONTROL_REPEAT_READ) {
        status = control_flow_monitor_advance(
            &monitor,
            CONTROL_FLOW_PHASE_START,
            CONTROL_FLOW_PHASE_READ_INPUT);
        (void)record_status(status);
        mirror_monitor(&monitor);
        return;
    }

    if (harness_fault_target == HARNESS_FAULT_CONTROL_SKIP_COMPUTE) {
        status = control_flow_monitor_advance(
            &monitor,
            CONTROL_FLOW_PHASE_COMPUTE,
            CONTROL_FLOW_PHASE_VALIDATE);
        (void)record_status(status);
        mirror_monitor(&monitor);
        return;
    }

    status = control_flow_monitor_advance(
        &monitor,
        CONTROL_FLOW_PHASE_READ_INPUT,
        CONTROL_FLOW_PHASE_COMPUTE);
    if (!control_flow_passed(record_status(status))) {
        mirror_monitor(&monitor);
        return;
    }

    computed = compute_value(input);
    harness_stage = HARNESS_STAGE_AFTER_CONTROL_COMPUTE;
    mirror_monitor(&monitor);

    if (harness_fault_target == HARNESS_FAULT_CONTROL_EARLY_TERMINAL) {
        const control_flow_status_t terminal_status =
            control_flow_monitor_finish(&monitor);
        harness_last_terminal_status = terminal_status;
        harness_last_status = terminal_status;
        mirror_monitor(&monitor);
        return;
    }

    status = control_flow_monitor_advance(
        &monitor,
        CONTROL_FLOW_PHASE_COMPUTE,
        CONTROL_FLOW_PHASE_VALIDATE);
    if (!control_flow_passed(record_status(status))) {
        mirror_monitor(&monitor);
        return;
    }

    status = control_flow_monitor_advance(
        &monitor,
        CONTROL_FLOW_PHASE_VALIDATE,
        CONTROL_FLOW_PHASE_COMMIT);
    if (!control_flow_passed(record_status(status))) {
        mirror_monitor(&monitor);
        return;
    }

    harness_last_value = computed;

    status = control_flow_monitor_advance(
        &monitor,
        CONTROL_FLOW_PHASE_COMMIT,
        CONTROL_FLOW_PHASE_DONE);
    if (!control_flow_passed(record_status(status))) {
        mirror_monitor(&monitor);
        return;
    }

    harness_last_terminal_status = control_flow_monitor_finish(&monitor);
    harness_last_status = harness_last_terminal_status;
    mirror_monitor(&monitor);
}

static void increment_passes(void) {
    harness_passes += 1u;
}

static void increment_failures(void) {
    harness_failures += 1u;
}

static void validate(uint32_t expected) {
    const uint32_t target = harness_last_fault_target;
    const uint32_t status = harness_last_status;
    const uint32_t control_status = harness_last_control_status;
    const uint32_t terminal_status = harness_last_terminal_status;
    const uint32_t phase = harness_last_phase;
    const uint32_t value = harness_last_value;

    switch (target) {
    case HARNESS_FAULT_CONTROL_PHASE:
    case HARNESS_FAULT_CONTROL_SKIP_COMPUTE:
    case HARNESS_FAULT_CONTROL_REPEAT_READ:
        if (status == HARNESS_CONTROL_INVALID_TRANSITION &&
            control_status == HARNESS_CONTROL_INVALID_TRANSITION &&
            terminal_status == HARNESS_CONTROL_OK &&
            value == 0u) {
            increment_passes();
        } else {
            increment_failures();
        }
        return;
    case HARNESS_FAULT_CONTROL_SIGNATURE:
        if (status == HARNESS_CONTROL_BAD_SIGNATURE &&
            control_status == HARNESS_CONTROL_BAD_SIGNATURE &&
            terminal_status == HARNESS_CONTROL_OK &&
            phase == CONTROL_FLOW_PHASE_READ_INPUT &&
            value == 0u) {
            increment_passes();
        } else {
            increment_failures();
        }
        return;
    case HARNESS_FAULT_CONTROL_EARLY_TERMINAL:
        if (status == HARNESS_CONTROL_UNEXPECTED_TERMINAL &&
            control_status == HARNESS_CONTROL_OK &&
            terminal_status == HARNESS_CONTROL_UNEXPECTED_TERMINAL &&
            phase == CONTROL_FLOW_PHASE_COMPUTE &&
            value == 0u) {
            increment_passes();
        } else {
            increment_failures();
        }
        return;
    default:
        if (status == HARNESS_CONTROL_OK &&
            control_status == HARNESS_CONTROL_OK &&
            terminal_status == HARNESS_CONTROL_OK &&
            phase == CONTROL_FLOW_PHASE_DONE &&
            value == expected) {
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
        const uint32_t input = pattern(iteration);
        const uint32_t expected = compute_value(input);

        harness_iteration = iteration;
        harness_last_expected = expected;
        harness_last_value = 0u;
        harness_last_status = HARNESS_CONTROL_OK;
        harness_last_control_status = HARNESS_CONTROL_OK;
        harness_last_terminal_status = HARNESS_CONTROL_OK;
        harness_last_phase = CONTROL_FLOW_PHASE_START;
        harness_last_signature =
            control_flow_phase_signature(CONTROL_FLOW_PHASE_START);
        harness_last_transitions = 0u;
        harness_last_fault_target = HARNESS_FAULT_NONE;

        harness_stage = HARNESS_STAGE_BEFORE_CONTROL_FLOW;
        harness_injection_point_before_control_flow();

        harness_last_fault_target = harness_fault_target;
        run_control_flow(input);
        harness_fault_target = HARNESS_FAULT_NONE;

        harness_stage = HARNESS_STAGE_AFTER_CONTROL_FLOW;
        validate(expected);
        harness_injection_point_after_control_flow();
    }
}

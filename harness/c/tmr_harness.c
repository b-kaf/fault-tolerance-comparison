#include <stdint.h>

#include "harness_abi.h"
#include "../../c/tmr/tmr.h"

volatile uint32_t harness_iteration;
volatile uint32_t harness_stage;
volatile uint32_t harness_fault_target;
volatile uint32_t harness_fault_value;
volatile uint32_t harness_last_expected;
volatile uint32_t harness_last_value;
volatile uint32_t harness_last_status;
volatile uint32_t harness_passes;
volatile uint32_t harness_failures;
volatile uint32_t harness_last_fault_target;
volatile tmr_int_t harness_c_tmr_state;

static uint32_t pattern(uint32_t iteration) {
    return 0x5a5a0000u ^ (iteration * 2654435761u);
}

__attribute__((used, noinline))
void harness_injection_point_after_init(void) {
    __asm__ volatile("nop");
}

__attribute__((used, noinline))
void harness_injection_point_after_read(void) {
    __asm__ volatile("nop");
}

static void apply_pending_fault(void) {
    const uint32_t target = harness_fault_target;
    const int value = (int)harness_fault_value;

    harness_last_fault_target = target;

    switch (target) {
    case HARNESS_FAULT_COPY_A:
        tmr_int_inject_fault_a((tmr_int_t *)&harness_c_tmr_state, value);
        break;
    case HARNESS_FAULT_ALL_DISTINCT:
        tmr_int_inject_all(
            (tmr_int_t *)&harness_c_tmr_state,
            value,
            value ^ 0x11111111,
            value ^ 0x22222222);
        break;
    default:
        break;
    }

    harness_fault_target = HARNESS_FAULT_NONE;
}

static void validate(uint32_t expected, uint32_t status, uint32_t value) {
    const uint32_t injected = harness_last_fault_target;
    const uint32_t expect_no_majority = injected == HARNESS_FAULT_ALL_DISTINCT;

    if (expect_no_majority) {
        if (status == HARNESS_STATUS_NO_MAJORITY) {
            harness_passes += 1;
        } else {
            harness_failures += 1;
        }
        return;
    }

    if (status == HARNESS_STATUS_OK && value == expected) {
        harness_passes += 1;
    } else {
        harness_failures += 1;
    }
}

void harness_main(void) {
    harness_stage = HARNESS_STAGE_BOOT;

    for (;;) {
        const uint32_t iteration = harness_iteration + 1;
        const uint32_t expected = pattern(iteration);
        int value = 0;
        tmr_status_t status;

        harness_iteration = iteration;
        harness_last_expected = expected;
        harness_last_value = 0;
        harness_last_status = HARNESS_STATUS_OK;
        harness_last_fault_target = HARNESS_FAULT_NONE;
        harness_c_tmr_state = tmr_int_init((int)expected);

        harness_stage = HARNESS_STAGE_AFTER_INIT;
        harness_injection_point_after_init();

        apply_pending_fault();

        harness_stage = HARNESS_STAGE_BEFORE_READ;
        status = tmr_int_read((tmr_int_t *)&harness_c_tmr_state, &value);

        harness_last_value = (uint32_t)value;
        harness_last_status = status == TMR_OK
            ? HARNESS_STATUS_OK
            : HARNESS_STATUS_NO_MAJORITY;

        harness_stage = HARNESS_STAGE_AFTER_READ;
        validate(expected, harness_last_status, harness_last_value);
        harness_injection_point_after_read();
    }
}

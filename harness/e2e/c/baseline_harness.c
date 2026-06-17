#include <stdint.h>

#include "harness_abi.h"

/* The baseline harness runs the same workflow as the combined harness, but
 * with no fault tolerance at all:
 *
 *   read_input  a single plain read
 *   compute     a single implementation, no acceptance test
 *   validate    (none)
 *   commit      a plain assignment, no checkpoint
 *   whole run   no control-flow monitor
 *
 * It shares the combined harness's workload (so `expected` matches) and the
 * same injected (target, value) faults, applied to the plain equivalents. With
 * nothing to mask, detect, or recover, every meaningful fault commits a wrong
 * value: the outcome is silent data corruption (HARNESS_OUTCOME_SDC). This is
 * the unprotected reference the combined harness is measured against. */

volatile uint32_t harness_iteration;
volatile uint32_t harness_stage;
volatile uint32_t harness_fault_target;
volatile uint32_t harness_fault_value;
volatile uint32_t harness_last_fault_target;
volatile uint32_t harness_last_expected;
volatile uint32_t harness_last_value;
volatile uint32_t harness_last_outcome;
volatile uint32_t harness_passes;
volatile uint32_t harness_failures;

static uint32_t sample_input(uint32_t iteration) {
    return 100u + ((iteration * 41u) % 700u);
}

/* Plain compute, replicating recovery_block_sample_primary_value so that the
 * baseline and combined harnesses agree on the expected output. */
static uint32_t compute_value(uint32_t sample) {
    const uint32_t reduced = sample % 700u;
    return 100u + (((reduced * 37u) + 17u) % 700u);
}

__attribute__((used, noinline))
void harness_injection_point_before_workflow(void) {
    __asm__ volatile("nop");
}

__attribute__((used, noinline))
void harness_injection_point_after_workflow(void) {
    __asm__ volatile("nop");
}

static void run_workflow(uint32_t input_seed) {
    const uint32_t target = harness_last_fault_target;
    const uint32_t value = harness_fault_value;
    uint32_t input = input_seed;
    uint32_t output;

    /* read_input (unprotected): a corrupted copy silently replaces the input. */
    harness_stage = HARNESS_STAGE_AFTER_CONTROL_READ;
    if (target == HARNESS_FAULT_COPY_A || target == HARNESS_FAULT_ALL_DISTINCT) {
        input = value;
    }

    /* control divergence (unprotected): nothing monitors the phase, so a
     * corrupted control path simply skips the compute step. */
    if (target == HARNESS_FAULT_CONTROL_PHASE ||
        target == HARNESS_FAULT_CONTROL_SIGNATURE) {
        harness_last_value = 0u; /* stale: compute never ran */
        return;
    }

    /* compute (unprotected): no acceptance test, no alternate. */
    harness_stage = HARNESS_STAGE_AFTER_CONTROL_COMPUTE;
    output = compute_value(input);
    if (target == HARNESS_FAULT_RECOVERY_PRIMARY_VALUE) {
        output = value;
    } else if (target == HARNESS_FAULT_RECOVERY_PRIMARY_CHECKSUM) {
        output ^= value;
    }

    /* commit (unprotected): no checkpoint, no validation gate. */
    if (target == HARNESS_FAULT_ACTIVE_VALUE) {
        output = value;
    } else if (target == HARNESS_FAULT_ACTIVE_CHECKSUM) {
        output ^= value;
    }

    harness_last_value = output;
}

static uint32_t classify_outcome(uint32_t expected) {
    return harness_last_value == expected
        ? HARNESS_OUTCOME_CORRECT
        : HARNESS_OUTCOME_SDC;
}

static void validate(void) {
    const uint32_t target = harness_last_fault_target;
    const uint32_t outcome = harness_last_outcome;
    int pass;

    if (target == HARNESS_FAULT_NONE) {
        pass = outcome == HARNESS_OUTCOME_CORRECT;
    } else {
        pass = outcome != HARNESS_OUTCOME_SDC;
    }

    if (pass) {
        harness_passes += 1u;
    } else {
        harness_failures += 1u;
    }
}

void harness_main(void) {
    harness_stage = HARNESS_STAGE_BOOT;

    for (;;) {
        const uint32_t iteration = harness_iteration + 1u;
        const uint32_t input = sample_input(iteration);
        const uint32_t expected = compute_value(input);

        harness_iteration = iteration;
        harness_last_expected = expected;
        harness_last_value = 0u;
        harness_last_outcome = HARNESS_OUTCOME_CORRECT;
        harness_last_fault_target = HARNESS_FAULT_NONE;

        harness_stage = HARNESS_STAGE_BEFORE_WORKFLOW;
        harness_injection_point_before_workflow();

        harness_last_fault_target = harness_fault_target;
        run_workflow(input);
        harness_fault_target = HARNESS_FAULT_NONE;

        harness_last_outcome = classify_outcome(expected);

        harness_stage = HARNESS_STAGE_AFTER_WORKFLOW;
        validate();
        harness_injection_point_after_workflow();
    }
}

#include <stdint.h>

#include "fuzz_common.h"

/* Single-shot baseline fuzz harness: runs the same workload as the combined
 * fuzz harness (so `expected` matches) but unprotected — a plain read and a
 * single compute, no voting, recovery, validation, checkpoint, or monitor. The
 * QEMU plugin injects one bit flip during the window; with nothing to mask or
 * detect it, a flip that lands on the live state silently corrupts the output
 * (SDC), while a harmless flip leaves the result correct. The live state is
 * exported as harness_fuzz_* so ram-bitflip can target it. */

volatile uint32_t harness_fuzz_baseline_input;
volatile uint32_t harness_fuzz_baseline_output;

static uint32_t sample_input(uint64_t *rng) {
    return 100u + (harness_random_u32(rng) % 700u);
}

/* Plain compute, replicating recovery_block_sample_primary_value so the
 * baseline and combined harnesses agree on the expected output. */
static uint32_t compute_value(uint32_t sample) {
    const uint32_t reduced = sample % 700u;
    return 100u + (((reduced * 37u) + 17u) % 700u);
}

__attribute__((noinline))
static void run_workflow(void) {
    harness_fuzz_baseline_output = compute_value(harness_fuzz_baseline_input);
}

void harness_main(void) {
    uint64_t rng = harness_seed_state();
    const uint32_t input = sample_input(&rng);
    const uint32_t expected = compute_value(input);

    harness_expected = expected;
    harness_fuzz_baseline_input = input;
    harness_fuzz_baseline_output = 0u;

    harness_open_fault_window();
    run_workflow();
    harness_close_fault_window();

    harness_output = harness_fuzz_baseline_output;

    harness_finish();
}

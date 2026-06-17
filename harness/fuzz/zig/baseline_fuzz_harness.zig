const fuzz = @import("fuzz_abi.zig");

// Single-shot baseline fuzz harness: runs the same workload as the combined
// fuzz harness (so `expected` matches) but unprotected — a plain read and a
// single compute, no voting, recovery, validation, checkpoint, or monitor. The
// QEMU plugin injects one bit flip during the window; with nothing to mask or
// detect it, a flip that lands on the live state silently corrupts the output
// (SDC), while a harmless flip leaves the result correct. The live state is
// exported as harness_fuzz_* so ram-bitflip can target it.

export var harness_fuzz_baseline_input: u32 = 0;
export var harness_fuzz_baseline_output: u32 = 0;

fn sampleInput(rng: *u64) u32 {
    return 100 + (fuzz.randomU32(rng) % 700);
}

// Plain compute, replicating recovery_block.samplePrimaryValue so the baseline
// and combined harnesses agree on the expected output.
fn computeValue(sample: u32) u32 {
    const reduced = sample % 700;
    return 100 + (((reduced *% 37) + 17) % 700);
}

fn runWorkflow() void {
    harness_fuzz_baseline_output = computeValue(harness_fuzz_baseline_input);
}

export fn harness_main() callconv(.c) noreturn {
    var rng = fuzz.seedState();
    const input = sampleInput(&rng);
    const expected = computeValue(input);

    fuzz.store32(&fuzz.harness_expected, expected);
    harness_fuzz_baseline_input = input;
    harness_fuzz_baseline_output = 0;

    fuzz.openFaultWindow();
    // never_inline keeps the load of harness_fuzz_baseline_input from being hoisted across the window.
    @call(.never_inline, runWorkflow, .{});
    fuzz.closeFaultWindow();

    fuzz.store32(&fuzz.harness_output, harness_fuzz_baseline_output);

    fuzz.complete();
}

pub const panic = fuzz.panic;

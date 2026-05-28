const checker = @import("checker");
const checkpoint = @import("checkpoint");
const fuzz = @import("fuzz_abi.zig");
const recovery_block = @import("recovery_block");

export var harness_fuzz_recovery_state: checkpoint.CheckpointedRecord = undefined;

fn sampleInitialValue(rng: *u64) u32 {
    return 100 + (fuzz.randomU32(rng) % 700);
}

fn sampleRecord(value: u32) checker.CheckedRecord {
    return checker.CheckedRecord.init(.sample, value, 0, 1000, 6, 16);
}

export fn harness_main() callconv(.c) noreturn {
    var rng = fuzz.seedState();
    const sample = fuzz.randomU32(&rng);
    const initial = sampleInitialValue(&rng);
    const expected = recovery_block.samplePrimaryValue(sample);
    const update = recovery_block.SampleUpdate{
        .sample = sample,
        .faults = recovery_block.sample_fault.none,
    };

    fuzz.store32(&fuzz.harness_expected, expected);
    harness_fuzz_recovery_state = checkpoint.CheckpointedRecord.init(sampleRecord(initial));

    fuzz.openFaultWindow();
    // never_inline keeps loads of harness_fuzz_recovery_state from being hoisted across the window.
    const result = @call(
        .never_inline,
        recovery_block.runSampleUpdate,
        .{ &harness_fuzz_recovery_state, update },
    );
    fuzz.closeFaultWindow();

    fuzz.store32(&fuzz.harness_output, harness_fuzz_recovery_state.active.value);
    fuzz.store32(&fuzz.harness_error_code, result.status.code());
    if (result.status != .primary_accepted or
        result.checkpoint_check != .ok or
        result.primary_check != .ok or
        result.restore_check != .ok or
        result.alternate_check != .ok)
    {
        fuzz.store32(&fuzz.harness_detected, 1);
    }
    if (fuzz.load32(&fuzz.harness_detected) != 0 and
        harness_fuzz_recovery_state.active.value == expected)
    {
        fuzz.store32(&fuzz.harness_corrected, 1);
    }
    if (result.status == .unrecoverable or
        result.status == .checkpoint_failed or
        result.status == .restore_failed)
    {
        fuzz.store32(&fuzz.harness_safe_state, 1);
    }

    fuzz.complete();
}

pub const panic = fuzz.panic;

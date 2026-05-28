const checker = @import("checker");
const checkpoint = @import("checkpoint");
const fuzz = @import("fuzz_abi.zig");

export var harness_fuzz_checkpoint_state: checkpoint.CheckpointedRecord = undefined;

fn sampleInitialValue(rng: *u64) u32 {
    return 100 + (fuzz.randomU32(rng) % 700);
}

fn sampleRecord(value: u32) checker.CheckedRecord {
    return checker.CheckedRecord.init(.sample, value, 0, 1000, 6, 16);
}

export fn harness_main() callconv(.c) noreturn {
    var rng = fuzz.seedState();
    const initial = sampleInitialValue(&rng);
    const expected = sampleInitialValue(&rng);

    fuzz.store32(&fuzz.harness_expected, expected);
    harness_fuzz_checkpoint_state = checkpoint.CheckpointedRecord.init(sampleRecord(initial));
    _ = harness_fuzz_checkpoint_state.capture();
    harness_fuzz_checkpoint_state.active.value = expected;
    harness_fuzz_checkpoint_state.active.refreshChecksum();

    fuzz.openFaultWindow();
    // never_inline keeps loads of harness_fuzz_checkpoint_state from being hoisted across the window.
    const result = @call(
        .never_inline,
        checkpoint.CheckpointedRecord.commitOrRestart,
        .{&harness_fuzz_checkpoint_state},
    );
    fuzz.closeFaultWindow();

    fuzz.store32(&fuzz.harness_output, harness_fuzz_checkpoint_state.active.value);
    fuzz.store32(&fuzz.harness_error_code, result.status.code());
    if (result.status != .committed or
        result.active_check != .ok or
        result.checkpoint_check != .ok)
    {
        fuzz.store32(&fuzz.harness_detected, 1);
    }
    if (fuzz.load32(&fuzz.harness_detected) != 0 and
        harness_fuzz_checkpoint_state.active.value == expected)
    {
        fuzz.store32(&fuzz.harness_corrected, 1);
    }
    if (result.status != .committed and
        harness_fuzz_checkpoint_state.active.value != expected)
    {
        fuzz.store32(&fuzz.harness_safe_state, 1);
    }

    fuzz.complete();
}

pub const panic = fuzz.panic;

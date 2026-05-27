const checkpoint = @import("checkpoint");
const checker = @import("checker");
const fuzz = @import("fuzz_abi.zig");
const recovery_block = @import("recovery_block");
const std = @import("std");

export var harness_fuzz_recovery_active_tag: u32 = 0;
export var harness_fuzz_recovery_active_value: u32 = 0;
export var harness_fuzz_recovery_active_min: u32 = 0;
export var harness_fuzz_recovery_active_max: u32 = 0;
export var harness_fuzz_recovery_active_length: u32 = 0;
export var harness_fuzz_recovery_active_capacity: u32 = 0;
export var harness_fuzz_recovery_active_checksum: u32 = 0;
export var harness_fuzz_recovery_saved_tag: u32 = 0;
export var harness_fuzz_recovery_saved_value: u32 = 0;
export var harness_fuzz_recovery_saved_min: u32 = 0;
export var harness_fuzz_recovery_saved_max: u32 = 0;
export var harness_fuzz_recovery_saved_length: u32 = 0;
export var harness_fuzz_recovery_saved_capacity: u32 = 0;
export var harness_fuzz_recovery_saved_checksum: u32 = 0;

fn sampleInitialValue(rng: *u64) u32 {
    return 100 + (fuzz.randomU32(rng) % 700);
}

fn sampleRecord(value: u32) checker.CheckedRecord {
    return checker.CheckedRecord.init(.sample, value, 0, 1000, 6, 16);
}

fn loadActiveRecord() checker.CheckedRecord {
    return .{
        .tag = fuzz.load32(&harness_fuzz_recovery_active_tag),
        .value = fuzz.load32(&harness_fuzz_recovery_active_value),
        .min = fuzz.load32(&harness_fuzz_recovery_active_min),
        .max = fuzz.load32(&harness_fuzz_recovery_active_max),
        .length = fuzz.load32(&harness_fuzz_recovery_active_length),
        .capacity = fuzz.load32(&harness_fuzz_recovery_active_capacity),
        .checksum = fuzz.load32(&harness_fuzz_recovery_active_checksum),
    };
}

fn loadSavedRecord() checker.CheckedRecord {
    return .{
        .tag = fuzz.load32(&harness_fuzz_recovery_saved_tag),
        .value = fuzz.load32(&harness_fuzz_recovery_saved_value),
        .min = fuzz.load32(&harness_fuzz_recovery_saved_min),
        .max = fuzz.load32(&harness_fuzz_recovery_saved_max),
        .length = fuzz.load32(&harness_fuzz_recovery_saved_length),
        .capacity = fuzz.load32(&harness_fuzz_recovery_saved_capacity),
        .checksum = fuzz.load32(&harness_fuzz_recovery_saved_checksum),
    };
}

fn loadState() checkpoint.CheckpointedRecord {
    return .{
        .active = loadActiveRecord(),
        .checkpoint = loadSavedRecord(),
    };
}

fn mirrorState(state: *const checkpoint.CheckpointedRecord) void {
    fuzz.store32(&harness_fuzz_recovery_active_tag, state.active.tag);
    fuzz.store32(&harness_fuzz_recovery_active_value, state.active.value);
    fuzz.store32(&harness_fuzz_recovery_active_min, state.active.min);
    fuzz.store32(&harness_fuzz_recovery_active_max, state.active.max);
    fuzz.store32(&harness_fuzz_recovery_active_length, state.active.length);
    fuzz.store32(&harness_fuzz_recovery_active_capacity, state.active.capacity);
    fuzz.store32(&harness_fuzz_recovery_active_checksum, state.active.checksum);
    fuzz.store32(&harness_fuzz_recovery_saved_tag, state.checkpoint.tag);
    fuzz.store32(&harness_fuzz_recovery_saved_value, state.checkpoint.value);
    fuzz.store32(&harness_fuzz_recovery_saved_min, state.checkpoint.min);
    fuzz.store32(&harness_fuzz_recovery_saved_max, state.checkpoint.max);
    fuzz.store32(&harness_fuzz_recovery_saved_length, state.checkpoint.length);
    fuzz.store32(&harness_fuzz_recovery_saved_capacity, state.checkpoint.capacity);
    fuzz.store32(&harness_fuzz_recovery_saved_checksum, state.checkpoint.checksum);
}

export fn harness_main() callconv(.c) noreturn {
    var rng = fuzz.seedState();
    const sample = fuzz.randomU32(&rng);
    const initial = sampleInitialValue(&rng);
    const expected = recovery_block.samplePrimaryValue(sample);
    var state = checkpoint.CheckpointedRecord.init(sampleRecord(initial));
    var update = recovery_block.SampleUpdate{
        .sample = sample,
        .faults = recovery_block.sample_fault.none,
    };

    fuzz.store32(&fuzz.harness_expected, expected);
    mirrorState(&state);

    fuzz.openFaultWindow();
    state = loadState();
    const result = recovery_block.run(
        &state,
        &update,
        recovery_block.samplePrimary,
        recovery_block.sampleAlternate,
    );
    mirrorState(&state);
    fuzz.closeFaultWindow();

    fuzz.store32(&fuzz.harness_output, state.active.value);
    fuzz.store32(&fuzz.harness_error_code, result.status.code());
    if (result.status != .primary_accepted or
        result.checkpoint_check != .ok or
        result.primary_check != .ok or
        result.restore_check != .ok or
        result.alternate_check != .ok)
    {
        fuzz.store32(&fuzz.harness_detected, 1);
    }
    if (fuzz.load32(&fuzz.harness_detected) != 0 and state.active.value == expected) {
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

pub fn panic(msg: []const u8, trace: ?*std.builtin.StackTrace, ra: ?usize) noreturn {
    _ = msg;
    _ = trace;
    _ = ra;
    while (true) {}
}

const checkpoint = @import("checkpoint");
const fuzz = @import("fuzz_abi.zig");
const mirror = @import("checked_record_mirror.zig");

export var harness_fuzz_checkpoint_active_tag: u32 = 0;
export var harness_fuzz_checkpoint_active_value: u32 = 0;
export var harness_fuzz_checkpoint_active_min: u32 = 0;
export var harness_fuzz_checkpoint_active_max: u32 = 0;
export var harness_fuzz_checkpoint_active_length: u32 = 0;
export var harness_fuzz_checkpoint_active_capacity: u32 = 0;
export var harness_fuzz_checkpoint_active_checksum: u32 = 0;
export var harness_fuzz_checkpoint_saved_tag: u32 = 0;
export var harness_fuzz_checkpoint_saved_value: u32 = 0;
export var harness_fuzz_checkpoint_saved_min: u32 = 0;
export var harness_fuzz_checkpoint_saved_max: u32 = 0;
export var harness_fuzz_checkpoint_saved_length: u32 = 0;
export var harness_fuzz_checkpoint_saved_capacity: u32 = 0;
export var harness_fuzz_checkpoint_saved_checksum: u32 = 0;

const ptrs = mirror.CheckpointedPtrs{
    .active = .{
        .tag = &harness_fuzz_checkpoint_active_tag,
        .value = &harness_fuzz_checkpoint_active_value,
        .min = &harness_fuzz_checkpoint_active_min,
        .max = &harness_fuzz_checkpoint_active_max,
        .length = &harness_fuzz_checkpoint_active_length,
        .capacity = &harness_fuzz_checkpoint_active_capacity,
        .checksum = &harness_fuzz_checkpoint_active_checksum,
    },
    .saved = .{
        .tag = &harness_fuzz_checkpoint_saved_tag,
        .value = &harness_fuzz_checkpoint_saved_value,
        .min = &harness_fuzz_checkpoint_saved_min,
        .max = &harness_fuzz_checkpoint_saved_max,
        .length = &harness_fuzz_checkpoint_saved_length,
        .capacity = &harness_fuzz_checkpoint_saved_capacity,
        .checksum = &harness_fuzz_checkpoint_saved_checksum,
    },
};

export fn harness_main() callconv(.c) noreturn {
    var rng = fuzz.seedState();
    const initial = mirror.sampleInitialValue(&rng);
    const expected = mirror.sampleInitialValue(&rng);
    var state = checkpoint.CheckpointedRecord.init(mirror.sampleRecord(initial));

    fuzz.store32(&fuzz.harness_expected, expected);
    _ = state.capture();
    state.active.value = expected;
    state.active.refreshChecksum();
    mirror.mirrorCheckpointed(ptrs, &state);

    fuzz.openFaultWindow();
    state = mirror.loadCheckpointed(ptrs);
    const result = state.commitOrRestart();
    mirror.mirrorCheckpointed(ptrs, &state);
    fuzz.closeFaultWindow();

    fuzz.store32(&fuzz.harness_output, state.active.value);
    fuzz.store32(&fuzz.harness_error_code, result.status.code());
    if (result.status != .committed or
        result.active_check != .ok or
        result.checkpoint_check != .ok)
    {
        fuzz.store32(&fuzz.harness_detected, 1);
    }
    if (fuzz.load32(&fuzz.harness_detected) != 0 and state.active.value == expected) {
        fuzz.store32(&fuzz.harness_corrected, 1);
    }
    if (result.status != .committed and state.active.value != expected) {
        fuzz.store32(&fuzz.harness_safe_state, 1);
    }

    fuzz.complete();
}

pub const panic = fuzz.panic;

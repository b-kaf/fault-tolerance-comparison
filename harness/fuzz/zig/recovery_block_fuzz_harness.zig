const checkpoint = @import("checkpoint");
const fuzz = @import("fuzz_abi.zig");
const mirror = @import("checked_record_mirror.zig");
const recovery_block = @import("recovery_block");

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

const ptrs = mirror.CheckpointedPtrs{
    .active = .{
        .tag = &harness_fuzz_recovery_active_tag,
        .value = &harness_fuzz_recovery_active_value,
        .min = &harness_fuzz_recovery_active_min,
        .max = &harness_fuzz_recovery_active_max,
        .length = &harness_fuzz_recovery_active_length,
        .capacity = &harness_fuzz_recovery_active_capacity,
        .checksum = &harness_fuzz_recovery_active_checksum,
    },
    .saved = .{
        .tag = &harness_fuzz_recovery_saved_tag,
        .value = &harness_fuzz_recovery_saved_value,
        .min = &harness_fuzz_recovery_saved_min,
        .max = &harness_fuzz_recovery_saved_max,
        .length = &harness_fuzz_recovery_saved_length,
        .capacity = &harness_fuzz_recovery_saved_capacity,
        .checksum = &harness_fuzz_recovery_saved_checksum,
    },
};

export fn harness_main() callconv(.c) noreturn {
    var rng = fuzz.seedState();
    const sample = fuzz.randomU32(&rng);
    const initial = mirror.sampleInitialValue(&rng);
    const expected = recovery_block.samplePrimaryValue(sample);
    var state = checkpoint.CheckpointedRecord.init(mirror.sampleRecord(initial));
    var update = recovery_block.SampleUpdate{
        .sample = sample,
        .faults = recovery_block.sample_fault.none,
    };

    fuzz.store32(&fuzz.harness_expected, expected);
    mirror.mirrorCheckpointed(ptrs, &state);

    state = mirror.loadCheckpointed(ptrs);
    fuzz.openFaultWindow();
    const result = recovery_block.run(
        &state,
        &update,
        recovery_block.samplePrimary,
        recovery_block.sampleAlternate,
    );
    fuzz.closeFaultWindow();
    mirror.mirrorCheckpointed(ptrs, &state);

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

pub const panic = fuzz.panic;

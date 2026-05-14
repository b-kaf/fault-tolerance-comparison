const std = @import("std");
const checker = @import("checker");
const checkpoint = @import("checkpoint");

pub const RecoveryStatus = enum(u32) {
    primary_accepted = 0,
    alternate_accepted = 1,
    unrecoverable = 2,
    checkpoint_failed = 3,
    restore_failed = 4,

    pub fn code(self: RecoveryStatus) u32 {
        return @intFromEnum(self);
    }
};

pub const Result = struct {
    status: RecoveryStatus,
    checkpoint_check: checker.CheckStatus,
    primary_check: checker.CheckStatus,
    restore_check: checker.CheckStatus,
    alternate_check: checker.CheckStatus,
};

pub const sample_fault = struct {
    pub const none: u32 = 0;
    pub const primary_range: u32 = 1 << 0;
    pub const primary_checksum: u32 = 1 << 1;
    pub const alternate_range: u32 = 1 << 2;
    pub const alternate_checksum: u32 = 1 << 3;
};

pub const SampleUpdate = struct {
    sample: u32,
    faults: u32,
};

fn initialResult() Result {
    return .{
        .status = .unrecoverable,
        .checkpoint_check = .ok,
        .primary_check = .ok,
        .restore_check = .ok,
        .alternate_check = .ok,
    };
}

pub fn run(
    state: *checkpoint.CheckpointedRecord,
    context: anytype,
    primary: *const fn (*checker.CheckedRecord, @TypeOf(context)) void,
    alternate: *const fn (*checker.CheckedRecord, @TypeOf(context)) void,
) Result {
    return runWithHooks(state, context, primary, null, alternate, null);
}

pub fn runWithHooks(
    state: *checkpoint.CheckpointedRecord,
    context: anytype,
    primary: *const fn (*checker.CheckedRecord, @TypeOf(context)) void,
    after_primary: ?*const fn (*checkpoint.CheckpointedRecord, @TypeOf(context)) void,
    alternate: *const fn (*checker.CheckedRecord, @TypeOf(context)) void,
    after_alternate: ?*const fn (*checkpoint.CheckpointedRecord, @TypeOf(context)) void,
) Result {
    var result = initialResult();

    result.checkpoint_check = state.capture();
    if (!result.checkpoint_check.passed()) {
        result.status = .checkpoint_failed;
        return result;
    }

    primary(&state.active, context);
    if (after_primary) |hook| {
        hook(state, context);
    }

    result.primary_check = state.active.validate();
    if (result.primary_check.passed()) {
        _ = state.capture();
        result.status = .primary_accepted;
        return result;
    }

    result.restore_check = state.restore();
    if (!result.restore_check.passed()) {
        result.status = .restore_failed;
        return result;
    }

    alternate(&state.active, context);
    if (after_alternate) |hook| {
        hook(state, context);
    }

    result.alternate_check = state.active.validate();
    if (result.alternate_check.passed()) {
        _ = state.capture();
        result.status = .alternate_accepted;
        return result;
    }

    result.restore_check = state.restore();
    result.status = if (result.restore_check.passed()) .unrecoverable else .restore_failed;
    return result;
}

pub fn samplePrimaryValue(sample: u32) u32 {
    const reduced = sample % 700;
    return 100 + (((reduced * 37) + 17) % 700);
}

pub fn sampleAlternateValue(sample: u32) u32 {
    const reduced = sample % 700;
    var acc: u32 = 17;
    var i: u32 = 0;

    while (i < 37) : (i += 1) {
        acc += reduced;
        acc %= 700;
    }

    return 100 + acc;
}

fn setAboveRange(active: *checker.CheckedRecord) void {
    active.value = active.max + 1;
    active.refreshChecksum();
}

pub fn samplePrimary(active: *checker.CheckedRecord, update: *const SampleUpdate) void {
    active.value = samplePrimaryValue(update.sample);
    active.refreshChecksum();

    if ((update.faults & sample_fault.primary_range) != 0) {
        setAboveRange(active);
    }
    if ((update.faults & sample_fault.primary_checksum) != 0) {
        active.checksum ^= 0x10;
    }
}

pub fn sampleAlternate(active: *checker.CheckedRecord, update: *const SampleUpdate) void {
    active.value = sampleAlternateValue(update.sample);
    active.refreshChecksum();

    if ((update.faults & sample_fault.alternate_range) != 0) {
        setAboveRange(active);
    }
    if ((update.faults & sample_fault.alternate_checksum) != 0) {
        active.checksum ^= 0x10;
    }
}

pub fn runSampleUpdate(
    state: *checkpoint.CheckpointedRecord,
    update: SampleUpdate,
) Result {
    return run(state, &update, samplePrimary, sampleAlternate);
}

fn cleanRecord() checker.CheckedRecord {
    return checker.CheckedRecord.init(.sample, 50, 0, 1000, 6, 16);
}

test "recovery block: status codes are stable ABI values" {
    try std.testing.expectEqual(@as(u32, 0), RecoveryStatus.primary_accepted.code());
    try std.testing.expectEqual(@as(u32, 1), RecoveryStatus.alternate_accepted.code());
    try std.testing.expectEqual(@as(u32, 2), RecoveryStatus.unrecoverable.code());
    try std.testing.expectEqual(@as(u32, 3), RecoveryStatus.checkpoint_failed.code());
    try std.testing.expectEqual(@as(u32, 4), RecoveryStatus.restore_failed.code());
}

test "recovery block: sample variants compute same accepted value" {
    var sample: u32 = 0;
    while (sample < 2000) : (sample += 137) {
        try std.testing.expectEqual(samplePrimaryValue(sample), sampleAlternateValue(sample));
    }
}

test "recovery block: primary success commits primary result" {
    var state = checkpoint.CheckpointedRecord.init(cleanRecord());
    const update = SampleUpdate{ .sample = 7, .faults = sample_fault.none };
    const expected = samplePrimaryValue(update.sample);

    const result = runSampleUpdate(&state, update);

    try std.testing.expectEqual(RecoveryStatus.primary_accepted, result.status);
    try std.testing.expectEqual(checker.CheckStatus.ok, result.checkpoint_check);
    try std.testing.expectEqual(checker.CheckStatus.ok, result.primary_check);
    try std.testing.expectEqual(checker.CheckStatus.ok, result.restore_check);
    try std.testing.expectEqual(checker.CheckStatus.ok, result.alternate_check);
    try std.testing.expectEqual(expected, state.active.value);
    try std.testing.expectEqual(expected, state.checkpoint.value);
    try std.testing.expectEqual(checker.CheckStatus.ok, state.active.validate());
    try std.testing.expectEqual(checker.CheckStatus.ok, state.checkpoint.validate());
}

test "recovery block: primary range failure recovers with alternate" {
    var state = checkpoint.CheckpointedRecord.init(cleanRecord());
    const update = SampleUpdate{ .sample = 11, .faults = sample_fault.primary_range };
    const expected = sampleAlternateValue(update.sample);

    const result = runSampleUpdate(&state, update);

    try std.testing.expectEqual(RecoveryStatus.alternate_accepted, result.status);
    try std.testing.expectEqual(checker.CheckStatus.ok, result.checkpoint_check);
    try std.testing.expectEqual(checker.CheckStatus.above_max, result.primary_check);
    try std.testing.expectEqual(checker.CheckStatus.ok, result.restore_check);
    try std.testing.expectEqual(checker.CheckStatus.ok, result.alternate_check);
    try std.testing.expectEqual(expected, state.active.value);
    try std.testing.expectEqual(expected, state.checkpoint.value);
    try std.testing.expectEqual(checker.CheckStatus.ok, state.active.validate());
}

test "recovery block: primary checksum failure recovers with alternate" {
    var state = checkpoint.CheckpointedRecord.init(cleanRecord());
    const update = SampleUpdate{ .sample = 13, .faults = sample_fault.primary_checksum };
    const expected = sampleAlternateValue(update.sample);

    const result = runSampleUpdate(&state, update);

    try std.testing.expectEqual(RecoveryStatus.alternate_accepted, result.status);
    try std.testing.expectEqual(checker.CheckStatus.invalid_checksum, result.primary_check);
    try std.testing.expectEqual(checker.CheckStatus.ok, result.restore_check);
    try std.testing.expectEqual(checker.CheckStatus.ok, result.alternate_check);
    try std.testing.expectEqual(expected, state.active.value);
    try std.testing.expectEqual(expected, state.checkpoint.value);
}

test "recovery block: alternate failure is unrecoverable and restores checkpoint" {
    var state = checkpoint.CheckpointedRecord.init(cleanRecord());
    const update = SampleUpdate{
        .sample = 17,
        .faults = sample_fault.primary_range | sample_fault.alternate_checksum,
    };

    const result = runSampleUpdate(&state, update);

    try std.testing.expectEqual(RecoveryStatus.unrecoverable, result.status);
    try std.testing.expectEqual(checker.CheckStatus.above_max, result.primary_check);
    try std.testing.expectEqual(checker.CheckStatus.ok, result.restore_check);
    try std.testing.expectEqual(checker.CheckStatus.invalid_checksum, result.alternate_check);
    try std.testing.expectEqual(@as(u32, 50), state.active.value);
    try std.testing.expectEqual(@as(u32, 50), state.checkpoint.value);
    try std.testing.expectEqual(checker.CheckStatus.ok, state.active.validate());
}

test "recovery block: invalid entry state fails before primary runs" {
    var state = checkpoint.CheckpointedRecord.init(cleanRecord());
    state.active.length = 20;
    const update = SampleUpdate{ .sample = 19, .faults = sample_fault.none };

    const result = runSampleUpdate(&state, update);

    try std.testing.expectEqual(RecoveryStatus.checkpoint_failed, result.status);
    try std.testing.expectEqual(checker.CheckStatus.invalid_length, result.checkpoint_check);
    try std.testing.expectEqual(checker.CheckStatus.ok, result.primary_check);
    try std.testing.expectEqual(checker.CheckStatus.ok, result.alternate_check);
    try std.testing.expectEqual(@as(u32, 20), state.active.length);
    try std.testing.expectEqual(@as(u32, 6), state.checkpoint.length);
}

fn failPrimaryRange(active: *checker.CheckedRecord, _: *const u32) void {
    active.value = active.max + 1;
    active.refreshChecksum();
}

fn validAlternateValue(active: *checker.CheckedRecord, value: *const u32) void {
    active.value = value.*;
    active.refreshChecksum();
}

fn corruptCheckpointChecksum(state: *checkpoint.CheckpointedRecord, _: *const u32) void {
    state.checkpoint.checksum ^= 0x10;
}

test "recovery block: corrupted checkpoint reports restore failure" {
    var state = checkpoint.CheckpointedRecord.init(cleanRecord());
    const expected: u32 = 123;

    const result = runWithHooks(
        &state,
        &expected,
        failPrimaryRange,
        corruptCheckpointChecksum,
        validAlternateValue,
        null,
    );

    try std.testing.expectEqual(RecoveryStatus.restore_failed, result.status);
    try std.testing.expectEqual(checker.CheckStatus.above_max, result.primary_check);
    try std.testing.expectEqual(checker.CheckStatus.invalid_checksum, result.restore_check);
    try std.testing.expectEqual(checker.CheckStatus.ok, result.alternate_check);
    try std.testing.expectEqual(@as(u32, 1001), state.active.value);
}

const std = @import("std");
const checker = @import("checker");

pub const RestartStatus = enum(u32) {
    committed = 0,
    restored = 1,
    restore_failed = 2,

    pub fn code(self: RestartStatus) u32 {
        return @intFromEnum(self);
    }
};

pub const RestartResult = struct {
    status: RestartStatus,
    active_check: checker.CheckStatus,
    checkpoint_check: checker.CheckStatus,
};

pub const CheckpointedRecord = extern struct {
    active: checker.CheckedRecord,
    checkpoint: checker.CheckedRecord,

    const Self = @This();

    pub fn init(initial: checker.CheckedRecord) Self {
        return .{
            .active = initial,
            .checkpoint = initial,
        };
    }

    pub fn capture(self: *Self) checker.CheckStatus {
        const active_check = self.active.validate();
        if (active_check.passed()) {
            self.checkpoint = self.active;
        }
        return active_check;
    }

    pub fn restore(self: *Self) checker.CheckStatus {
        const checkpoint_check = self.checkpoint.validate();
        if (checkpoint_check.passed()) {
            self.active = self.checkpoint;
        }
        return checkpoint_check;
    }

    pub fn commitOrRestart(self: *Self) RestartResult {
        const active_check = self.active.validate();
        if (active_check.passed()) {
            self.checkpoint = self.active;
            return .{
                .status = .committed,
                .active_check = active_check,
                .checkpoint_check = .ok,
            };
        }

        const checkpoint_check = self.checkpoint.validate();
        if (checkpoint_check.passed()) {
            self.active = self.checkpoint;
            return .{
                .status = .restored,
                .active_check = active_check,
                .checkpoint_check = checkpoint_check,
            };
        }

        return .{
            .status = .restore_failed,
            .active_check = active_check,
            .checkpoint_check = checkpoint_check,
        };
    }
};

fn cleanRecord() checker.CheckedRecord {
    return checker.CheckedRecord.init(.sample, 50, 10, 100, 3, 8);
}

test "checkpoint: restart status codes are stable ABI values" {
    try std.testing.expectEqual(@as(u32, 0), RestartStatus.committed.code());
    try std.testing.expectEqual(@as(u32, 1), RestartStatus.restored.code());
    try std.testing.expectEqual(@as(u32, 2), RestartStatus.restore_failed.code());
}

test "checkpoint: init mirrors initial state into active and checkpoint" {
    const state = CheckpointedRecord.init(cleanRecord());

    try std.testing.expectEqual(@as(u32, 50), state.active.value);
    try std.testing.expectEqual(@as(u32, 50), state.checkpoint.value);
    try std.testing.expectEqual(checker.CheckStatus.ok, state.active.validate());
    try std.testing.expectEqual(checker.CheckStatus.ok, state.checkpoint.validate());
}

test "checkpoint: capture valid active state updates checkpoint" {
    var state = CheckpointedRecord.init(cleanRecord());

    state.active.value = 60;
    state.active.refreshChecksum();

    try std.testing.expectEqual(checker.CheckStatus.ok, state.capture());
    try std.testing.expectEqual(@as(u32, 60), state.checkpoint.value);
    try std.testing.expectEqual(checker.CheckStatus.ok, state.checkpoint.validate());
}

test "checkpoint: capture rejects invalid active state and preserves checkpoint" {
    var state = CheckpointedRecord.init(cleanRecord());

    state.active.value = 101;

    try std.testing.expectEqual(checker.CheckStatus.above_max, state.capture());
    try std.testing.expectEqual(@as(u32, 50), state.checkpoint.value);
    try std.testing.expectEqual(checker.CheckStatus.ok, state.checkpoint.validate());
}

test "checkpoint: restore replaces corrupted active state from valid checkpoint" {
    var state = CheckpointedRecord.init(cleanRecord());

    state.active.value = 101;

    try std.testing.expectEqual(checker.CheckStatus.ok, state.restore());
    try std.testing.expectEqual(@as(u32, 50), state.active.value);
    try std.testing.expectEqual(checker.CheckStatus.ok, state.active.validate());
}

test "checkpoint: commit accepts valid active state and advances checkpoint" {
    var state = CheckpointedRecord.init(cleanRecord());

    state.active.value = 60;
    state.active.refreshChecksum();
    const result = state.commitOrRestart();

    try std.testing.expectEqual(RestartStatus.committed, result.status);
    try std.testing.expectEqual(checker.CheckStatus.ok, result.active_check);
    try std.testing.expectEqual(checker.CheckStatus.ok, result.checkpoint_check);
    try std.testing.expectEqual(@as(u32, 60), state.active.value);
    try std.testing.expectEqual(@as(u32, 60), state.checkpoint.value);
}

test "checkpoint: commit restarts invalid active state from checkpoint" {
    var state = CheckpointedRecord.init(cleanRecord());

    state.active.length = 9;
    const result = state.commitOrRestart();

    try std.testing.expectEqual(RestartStatus.restored, result.status);
    try std.testing.expectEqual(checker.CheckStatus.invalid_length, result.active_check);
    try std.testing.expectEqual(checker.CheckStatus.ok, result.checkpoint_check);
    try std.testing.expectEqual(@as(u32, 3), state.active.length);
    try std.testing.expectEqual(checker.CheckStatus.ok, state.active.validate());
}

test "checkpoint: commit reports restore failure when checkpoint is invalid" {
    var state = CheckpointedRecord.init(cleanRecord());

    state.active.value = 101;
    state.checkpoint.checksum ^= 0x10;
    const result = state.commitOrRestart();

    try std.testing.expectEqual(RestartStatus.restore_failed, result.status);
    try std.testing.expectEqual(checker.CheckStatus.above_max, result.active_check);
    try std.testing.expectEqual(checker.CheckStatus.invalid_checksum, result.checkpoint_check);
    try std.testing.expectEqual(@as(u32, 101), state.active.value);
}

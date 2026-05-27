const checkpoint = @import("checkpoint");
const checker = @import("checker");
const abi = @import("abi");
const std = @import("std");

comptime {
    std.debug.assert(abi.restart.committed == @intFromEnum(checkpoint.RestartStatus.committed));
    std.debug.assert(abi.restart.restored == @intFromEnum(checkpoint.RestartStatus.restored));
    std.debug.assert(abi.restart.restore_failed == @intFromEnum(checkpoint.RestartStatus.restore_failed));
}

const check = struct {
    const ok: u32 = @intFromEnum(checker.CheckStatus.ok);
    const above_max: u32 = @intFromEnum(checker.CheckStatus.above_max);
    const invalid_length: u32 = @intFromEnum(checker.CheckStatus.invalid_length);
    const invalid_checksum: u32 = @intFromEnum(checker.CheckStatus.invalid_checksum);
};

export var harness_iteration: u32 = 0;
export var harness_stage: u32 = 0;
export var harness_fault_target: u32 = 0;
export var harness_fault_value: u32 = 0;
export var harness_last_expected: u32 = 0;
export var harness_last_initial_value: u32 = 0;
export var harness_last_value: u32 = 0;
export var harness_last_status: u32 = 0;
export var harness_last_restart_status: u32 = 0;
export var harness_last_active_check: u32 = 0;
export var harness_last_checkpoint_check: u32 = 0;
export var harness_last_active_value: u32 = 0;
export var harness_last_checkpoint_value: u32 = 0;
export var harness_passes: u32 = 0;
export var harness_failures: u32 = 0;
export var harness_last_fault_target: u32 = 0;

export var harness_zig_active_tag: u32 = 0;
export var harness_zig_active_value: u32 = 0;
export var harness_zig_active_min: u32 = 0;
export var harness_zig_active_max: u32 = 0;
export var harness_zig_active_length: u32 = 0;
export var harness_zig_active_capacity: u32 = 0;
export var harness_zig_active_checksum: u32 = 0;
export var harness_zig_checkpoint_tag: u32 = 0;
export var harness_zig_checkpoint_value: u32 = 0;
export var harness_zig_checkpoint_min: u32 = 0;
export var harness_zig_checkpoint_max: u32 = 0;
export var harness_zig_checkpoint_length: u32 = 0;
export var harness_zig_checkpoint_capacity: u32 = 0;
export var harness_zig_checkpoint_checksum: u32 = 0;

fn load(ptr: *const volatile u32) u32 {
    return ptr.*;
}

fn store(ptr: *volatile u32, value: u32) void {
    ptr.* = value;
}

fn sampleInitialValue(iteration: u32) u32 {
    return 100 + ((iteration *% 37) % 700);
}

fn sampleUpdatedValue(iteration: u32) u32 {
    return 100 + (((iteration *% 53) +% 211) % 700);
}

fn sampleRecord(value: u32) checker.CheckedRecord {
    return checker.CheckedRecord.init(
        .sample,
        value,
        0,
        1000,
        6,
        16,
    );
}

fn loadActiveRecord() checker.CheckedRecord {
    return .{
        .tag = load(&harness_zig_active_tag),
        .value = load(&harness_zig_active_value),
        .min = load(&harness_zig_active_min),
        .max = load(&harness_zig_active_max),
        .length = load(&harness_zig_active_length),
        .capacity = load(&harness_zig_active_capacity),
        .checksum = load(&harness_zig_active_checksum),
    };
}

fn loadCheckpointRecord() checker.CheckedRecord {
    return .{
        .tag = load(&harness_zig_checkpoint_tag),
        .value = load(&harness_zig_checkpoint_value),
        .min = load(&harness_zig_checkpoint_min),
        .max = load(&harness_zig_checkpoint_max),
        .length = load(&harness_zig_checkpoint_length),
        .capacity = load(&harness_zig_checkpoint_capacity),
        .checksum = load(&harness_zig_checkpoint_checksum),
    };
}

fn loadState() checkpoint.CheckpointedRecord {
    return .{
        .active = loadActiveRecord(),
        .checkpoint = loadCheckpointRecord(),
    };
}

fn mirrorState(state: *const checkpoint.CheckpointedRecord) void {
    store(&harness_last_active_value, state.active.value);
    store(&harness_last_checkpoint_value, state.checkpoint.value);
    store(&harness_zig_active_tag, state.active.tag);
    store(&harness_zig_active_value, state.active.value);
    store(&harness_zig_active_min, state.active.min);
    store(&harness_zig_active_max, state.active.max);
    store(&harness_zig_active_length, state.active.length);
    store(&harness_zig_active_capacity, state.active.capacity);
    store(&harness_zig_active_checksum, state.active.checksum);
    store(&harness_zig_checkpoint_tag, state.checkpoint.tag);
    store(&harness_zig_checkpoint_value, state.checkpoint.value);
    store(&harness_zig_checkpoint_min, state.checkpoint.min);
    store(&harness_zig_checkpoint_max, state.checkpoint.max);
    store(&harness_zig_checkpoint_length, state.checkpoint.length);
    store(&harness_zig_checkpoint_capacity, state.checkpoint.capacity);
    store(&harness_zig_checkpoint_checksum, state.checkpoint.checksum);
}

export fn harness_injection_point_after_mutation() callconv(.c) void {
    asm volatile ("nop // injection_point_after_mutation");
}

export fn harness_injection_point_after_commit() callconv(.c) void {
    asm volatile ("nop // injection_point_after_commit");
}

fn applyPendingFault(state: *checkpoint.CheckpointedRecord) void {
    const target = load(&harness_fault_target);
    const value = load(&harness_fault_value);

    store(&harness_last_fault_target, target);

    switch (target) {
        abi.fault.active_value => state.active.value = value,
        abi.fault.active_length => state.active.length = value,
        abi.fault.active_checksum => state.active.checksum ^= value,
        abi.fault.checkpoint_value => state.checkpoint.value = value,
        abi.fault.checkpoint_checksum => state.checkpoint.checksum ^= value,
        abi.fault.active_value_and_checkpoint_checksum => {
            state.active.value = value;
            state.checkpoint.checksum ^= 0x10;
        },
        else => {},
    }

    store(&harness_fault_target, abi.fault.none);
    mirrorState(state);
}

fn incrementPasses() void {
    store(&harness_passes, load(&harness_passes) +% 1);
}

fn incrementFailures() void {
    store(&harness_failures, load(&harness_failures) +% 1);
}

fn validate(initial: u32, expected: u32) void {
    const target = load(&harness_last_fault_target);
    const restart = load(&harness_last_restart_status);
    const active_check = load(&harness_last_active_check);
    const checkpoint_check = load(&harness_last_checkpoint_check);
    const active_value = load(&harness_last_active_value);
    const checkpoint_value = load(&harness_last_checkpoint_value);

    switch (target) {
        abi.fault.active_value => {
            if (restart == abi.restart.restored and
                active_check == check.above_max and
                checkpoint_check == check.ok and
                active_value == initial and
                checkpoint_value == initial)
            {
                incrementPasses();
            } else {
                incrementFailures();
            }
        },
        abi.fault.active_length => {
            if (restart == abi.restart.restored and
                active_check == check.invalid_length and
                checkpoint_check == check.ok and
                active_value == initial and
                checkpoint_value == initial)
            {
                incrementPasses();
            } else {
                incrementFailures();
            }
        },
        abi.fault.active_checksum => {
            if (restart == abi.restart.restored and
                active_check == check.invalid_checksum and
                checkpoint_check == check.ok and
                active_value == initial and
                checkpoint_value == initial)
            {
                incrementPasses();
            } else {
                incrementFailures();
            }
        },
        abi.fault.active_value_and_checkpoint_checksum => {
            if (restart == abi.restart.restore_failed and
                active_check == check.above_max and
                checkpoint_check == check.invalid_checksum and
                active_value == load(&harness_fault_value))
            {
                incrementPasses();
            } else {
                incrementFailures();
            }
        },
        else => {
            if (restart == abi.restart.committed and
                active_check == check.ok and
                checkpoint_check == check.ok and
                active_value == expected and
                checkpoint_value == expected)
            {
                incrementPasses();
            } else {
                incrementFailures();
            }
        },
    }
}

export fn harness_main() callconv(.c) noreturn {
    store(&harness_stage, abi.stage.boot);

    while (true) {
        const iteration = load(&harness_iteration) +% 1;
        const initial = sampleInitialValue(iteration);
        const expected = sampleUpdatedValue(iteration);
        var state = checkpoint.CheckpointedRecord.init(sampleRecord(initial));

        store(&harness_iteration, iteration);
        store(&harness_last_initial_value, initial);
        store(&harness_last_expected, expected);
        store(&harness_last_value, 0);
        store(&harness_last_status, abi.status.ok);
        store(&harness_last_restart_status, abi.restart.committed);
        store(&harness_last_active_check, check.ok);
        store(&harness_last_checkpoint_check, check.ok);
        store(&harness_last_fault_target, abi.fault.none);

        store(&harness_stage, abi.stage.after_checkpoint);
        _ = state.capture();

        state.active.value = expected;
        state.active.refreshChecksum();
        mirrorState(&state);

        store(&harness_stage, abi.stage.after_mutation);
        @call(.never_inline, harness_injection_point_after_mutation, .{});

        state = loadState();
        applyPendingFault(&state);

        store(&harness_stage, abi.stage.before_commit);
        const result = state.commitOrRestart();

        store(&harness_last_restart_status, result.status.code());
        store(&harness_last_active_check, result.active_check.code());
        store(&harness_last_checkpoint_check, result.checkpoint_check.code());
        mirrorState(&state);
        store(&harness_last_value, load(&harness_last_active_value));

        store(&harness_stage, abi.stage.after_commit);
        validate(initial, expected);
        @call(.never_inline, harness_injection_point_after_commit, .{});
    }
}

pub fn panic(msg: []const u8, trace: ?*std.builtin.StackTrace, ra: ?usize) noreturn {
    _ = msg;
    _ = trace;
    _ = ra;
    while (true) {}
}

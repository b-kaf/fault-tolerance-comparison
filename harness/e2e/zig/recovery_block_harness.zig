const abi = @import("abi");
const checker = @import("checker");
const checkpoint = @import("checkpoint");
const recovery_block = @import("recovery_block");
const std = @import("std");

comptime {
    std.debug.assert(abi.recovery.primary_accepted == @intFromEnum(recovery_block.RecoveryStatus.primary_accepted));
    std.debug.assert(abi.recovery.alternate_accepted == @intFromEnum(recovery_block.RecoveryStatus.alternate_accepted));
    std.debug.assert(abi.recovery.unrecoverable == @intFromEnum(recovery_block.RecoveryStatus.unrecoverable));
    std.debug.assert(abi.recovery.checkpoint_failed == @intFromEnum(recovery_block.RecoveryStatus.checkpoint_failed));
    std.debug.assert(abi.recovery.restore_failed == @intFromEnum(recovery_block.RecoveryStatus.restore_failed));
}

const check = struct {
    const ok: u32 = @intFromEnum(checker.CheckStatus.ok);
    const above_max: u32 = @intFromEnum(checker.CheckStatus.above_max);
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
export var harness_last_recovery_status: u32 = 0;
export var harness_last_checkpoint_check: u32 = 0;
export var harness_last_primary_check: u32 = 0;
export var harness_last_restore_check: u32 = 0;
export var harness_last_alternate_check: u32 = 0;
export var harness_last_active_value: u32 = 0;
export var harness_last_checkpoint_value: u32 = 0;
export var harness_passes: u32 = 0;
export var harness_failures: u32 = 0;
export var harness_last_fault_target: u32 = 0;

// Working checkpointed record. Held in a single contiguous struct so it is
// memory-resident at the injection point and corruptible exactly like the C
// harness's `harness_recovery_block_state`. The algorithm runs in place on it;
// mirrorState only publishes the two observable values the tooling reads.
export var harness_recovery_block_state: checkpoint.CheckpointedRecord = undefined;

fn load(ptr: *const volatile u32) u32 {
    return ptr.*;
}

fn store(ptr: *volatile u32, value: u32) void {
    ptr.* = value;
}

fn sampleInitialValue(iteration: u32) u32 {
    return 100 + ((iteration *% 29) % 700);
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

fn mirrorState() void {
    store(&harness_last_active_value, harness_recovery_block_state.active.value);
    store(&harness_last_checkpoint_value, harness_recovery_block_state.checkpoint.value);
}

export fn harness_injection_point_before_recovery() callconv(.c) void {
    asm volatile ("nop // injection_point_before_recovery");
}

export fn harness_injection_point_after_recovery() callconv(.c) void {
    asm volatile ("nop // injection_point_after_recovery");
}

fn setPrimaryValueFault(state: *checkpoint.CheckpointedRecord) void {
    state.active.value = load(&harness_fault_value);
}

fn applyAfterPrimaryFault(
    state: *checkpoint.CheckpointedRecord,
    _: *const recovery_block.SampleUpdate,
) void {
    store(&harness_stage, abi.stage.after_primary);

    switch (load(&harness_fault_target)) {
        abi.fault.recovery_primary_value,
        abi.fault.recovery_primary_value_and_alternate_checksum,
        => setPrimaryValueFault(state),
        abi.fault.recovery_primary_checksum => state.active.checksum ^= load(&harness_fault_value),
        abi.fault.recovery_primary_value_and_checkpoint_checksum => {
            setPrimaryValueFault(state);
            state.checkpoint.checksum ^= 0x10;
        },
        else => {},
    }

    mirrorState();
}

fn applyAfterAlternateFault(
    state: *checkpoint.CheckpointedRecord,
    _: *const recovery_block.SampleUpdate,
) void {
    store(&harness_stage, abi.stage.after_alternate);

    if (load(&harness_fault_target) ==
        abi.fault.recovery_primary_value_and_alternate_checksum)
    {
        state.active.checksum ^= 0x10;
    }

    mirrorState();
}

fn incrementPasses() void {
    store(&harness_passes, load(&harness_passes) +% 1);
}

fn incrementFailures() void {
    store(&harness_failures, load(&harness_failures) +% 1);
}

fn validate(initial: u32, expected: u32) void {
    const target = load(&harness_last_fault_target);
    const recovery_status = load(&harness_last_recovery_status);
    const checkpoint_check = load(&harness_last_checkpoint_check);
    const primary_check = load(&harness_last_primary_check);
    const restore_check = load(&harness_last_restore_check);
    const alternate_check = load(&harness_last_alternate_check);
    const active_value = load(&harness_last_active_value);
    const checkpoint_value = load(&harness_last_checkpoint_value);

    switch (target) {
        abi.fault.recovery_primary_value => {
            if (recovery_status == abi.recovery.alternate_accepted and
                checkpoint_check == check.ok and
                primary_check == check.above_max and
                restore_check == check.ok and
                alternate_check == check.ok and
                active_value == expected and
                checkpoint_value == expected)
            {
                incrementPasses();
            } else {
                incrementFailures();
            }
        },
        abi.fault.recovery_primary_checksum => {
            if (recovery_status == abi.recovery.alternate_accepted and
                checkpoint_check == check.ok and
                primary_check == check.invalid_checksum and
                restore_check == check.ok and
                alternate_check == check.ok and
                active_value == expected and
                checkpoint_value == expected)
            {
                incrementPasses();
            } else {
                incrementFailures();
            }
        },
        abi.fault.recovery_primary_value_and_alternate_checksum => {
            if (recovery_status == abi.recovery.unrecoverable and
                checkpoint_check == check.ok and
                primary_check == check.above_max and
                restore_check == check.ok and
                alternate_check == check.invalid_checksum and
                active_value == initial and
                checkpoint_value == initial)
            {
                incrementPasses();
            } else {
                incrementFailures();
            }
        },
        abi.fault.recovery_primary_value_and_checkpoint_checksum => {
            if (recovery_status == abi.recovery.restore_failed and
                checkpoint_check == check.ok and
                primary_check == check.above_max and
                restore_check == check.invalid_checksum and
                alternate_check == check.ok and
                active_value == load(&harness_fault_value))
            {
                incrementPasses();
            } else {
                incrementFailures();
            }
        },
        else => {
            if (recovery_status == abi.recovery.primary_accepted and
                checkpoint_check == check.ok and
                primary_check == check.ok and
                restore_check == check.ok and
                alternate_check == check.ok and
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
        const expected = recovery_block.samplePrimaryValue(iteration);
        var update = recovery_block.SampleUpdate{
            .sample = iteration,
            .faults = recovery_block.sample_fault.none,
        };

        harness_recovery_block_state = checkpoint.CheckpointedRecord.init(sampleRecord(initial));

        store(&harness_iteration, iteration);
        store(&harness_last_initial_value, initial);
        store(&harness_last_expected, expected);
        store(&harness_last_value, 0);
        store(&harness_last_status, abi.recovery.primary_accepted);
        store(&harness_last_recovery_status, abi.recovery.primary_accepted);
        store(&harness_last_checkpoint_check, check.ok);
        store(&harness_last_primary_check, check.ok);
        store(&harness_last_restore_check, check.ok);
        store(&harness_last_alternate_check, check.ok);
        store(&harness_last_fault_target, abi.fault.none);
        mirrorState();

        store(&harness_stage, abi.stage.before_recovery);
        @call(.never_inline, harness_injection_point_before_recovery, .{});

        store(&harness_last_fault_target, load(&harness_fault_target));
        const result = recovery_block.runWithHooks(
            &harness_recovery_block_state,
            &update,
            recovery_block.samplePrimary,
            applyAfterPrimaryFault,
            recovery_block.sampleAlternate,
            applyAfterAlternateFault,
        );

        store(&harness_last_recovery_status, result.status.code());
        store(&harness_last_status, result.status.code());
        store(&harness_last_checkpoint_check, result.checkpoint_check.code());
        store(&harness_last_primary_check, result.primary_check.code());
        store(&harness_last_restore_check, result.restore_check.code());
        store(&harness_last_alternate_check, result.alternate_check.code());
        mirrorState();
        store(&harness_last_value, load(&harness_last_active_value));
        store(&harness_fault_target, abi.fault.none);

        store(&harness_stage, abi.stage.after_recovery);
        validate(initial, expected);
        @call(.never_inline, harness_injection_point_after_recovery, .{});
    }
}

pub fn panic(msg: []const u8, trace: ?*std.builtin.StackTrace, ra: ?usize) noreturn {
    _ = msg;
    _ = trace;
    _ = ra;
    while (true) {}
}

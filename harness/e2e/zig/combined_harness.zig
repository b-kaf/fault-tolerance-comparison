const abi = @import("abi");
const tmr = @import("tmr");
const checker = @import("checker");
const checkpoint = @import("checkpoint");
const recovery_block = @import("recovery_block");
const control_flow = @import("control_flow");
const std = @import("std");

// The combined harness runs one workflow that chains every technique:
//
//   start -> read_input -> compute -> validate -> commit -> done
//
//   read_input  TMR triplet, majority vote
//   compute     recovery block (primary -> acceptance test -> alternate)
//   validate    checker acceptance gate
//   commit      checkpoint commit-or-restart
//   whole run   control-flow signature monitor wraps every transition
//
// A single inject point sets the (target, value) pair; the workflow applies
// each fault at its natural phase. The final outcome is classified into
// abi.outcome.* and a pass means the protected workflow avoided silent data
// corruption. The baseline harness runs the identical workload unprotected.

comptime {
    std.debug.assert(abi.status.ok == 0);
    std.debug.assert(abi.status.no_majority == 1);
    std.debug.assert(abi.recovery.primary_accepted == @intFromEnum(recovery_block.RecoveryStatus.primary_accepted));
    std.debug.assert(abi.recovery.alternate_accepted == @intFromEnum(recovery_block.RecoveryStatus.alternate_accepted));
    std.debug.assert(abi.restart.committed == @intFromEnum(checkpoint.RestartStatus.committed));
    std.debug.assert(abi.restart.restored == @intFromEnum(checkpoint.RestartStatus.restored));
    std.debug.assert(abi.restart.restore_failed == @intFromEnum(checkpoint.RestartStatus.restore_failed));
    std.debug.assert(abi.control.ok == @intFromEnum(control_flow.ControlStatus.ok));
    std.debug.assert(abi.control.invalid_transition == @intFromEnum(control_flow.ControlStatus.invalid_transition));
    std.debug.assert(abi.control.bad_signature == @intFromEnum(control_flow.ControlStatus.bad_signature));
}

const TmrU32 = tmr.Tmr(u32);

export var harness_iteration: u32 = 0;
export var harness_stage: u32 = 0;
export var harness_fault_target: u32 = 0;
export var harness_fault_value: u32 = 0;
export var harness_last_fault_target: u32 = 0;
export var harness_last_expected: u32 = 0;
export var harness_last_value: u32 = 0;
export var harness_last_outcome: u32 = 0;
export var harness_last_tmr_status: u32 = 0;
export var harness_last_recovery_status: u32 = 0;
export var harness_last_restart_status: u32 = 0;
export var harness_last_control_status: u32 = 0;
export var harness_last_active_check: u32 = 0;
export var harness_last_checkpoint_check: u32 = 0;
export var harness_last_phase: u32 = 0;
export var harness_last_transitions: u32 = 0;
export var harness_passes: u32 = 0;
export var harness_failures: u32 = 0;

// Working state for the TMR vote and the recovery/checkpoint record. Both are
// initialized before the injection point and operated on in place, so they are
// memory-resident and corruptible exactly like the C harness's
// `harness_combined_tmr` / `harness_combined_record`. The control-flow monitor
// stays a local (as in C) since it is created fresh inside the workflow.
export var harness_combined_tmr: TmrU32 = undefined;
export var harness_combined_record: checkpoint.CheckpointedRecord = undefined;

fn load(ptr: *const volatile u32) u32 {
    return ptr.*;
}

fn store(ptr: *volatile u32, value: u32) void {
    ptr.* = value;
}

fn sampleInput(iteration: u32) u32 {
    return 100 + ((iteration *% 41) % 700);
}

fn sampleRecord(value: u32) checker.CheckedRecord {
    return checker.CheckedRecord.init(.sample, value, 0, 1000, 6, 16);
}

export fn harness_injection_point_before_workflow() callconv(.c) void {
    asm volatile ("nop // injection_point_before_workflow");
}

export fn harness_injection_point_after_workflow() callconv(.c) void {
    asm volatile ("nop // injection_point_after_workflow");
}

fn mirrorMonitor(monitor: *const control_flow.Monitor) void {
    store(&harness_last_phase, monitor.phase);
    store(&harness_last_transitions, monitor.transitions);
}

// read_input: corrupt the TMR triplet before the majority vote.
fn applyTmrFault(triplet: *TmrU32) void {
    const value = load(&harness_fault_value);
    switch (load(&harness_last_fault_target)) {
        abi.fault.copy_a => triplet.injectFaultA(value),
        abi.fault.all_distinct => triplet.injectAll(
            value,
            value ^ 0x11111111,
            value ^ 0x22222222,
        ),
        else => {},
    }
}

// compute: corrupt the primary result so the acceptance test rejects it and
// the recovery block falls through to the alternate.
fn applyAfterPrimaryFault(
    state: *checkpoint.CheckpointedRecord,
    _: *const recovery_block.SampleUpdate,
) void {
    store(&harness_stage, abi.stage.after_primary);
    switch (load(&harness_last_fault_target)) {
        abi.fault.recovery_primary_value => state.active.value = load(&harness_fault_value),
        abi.fault.recovery_primary_checksum => state.active.checksum ^= load(&harness_fault_value),
        else => {},
    }
}

fn applyAfterAlternateFault(
    _: *checkpoint.CheckpointedRecord,
    _: *const recovery_block.SampleUpdate,
) void {
    store(&harness_stage, abi.stage.after_alternate);
}

// control: corrupt the monitor between read_input and compute.
fn applyControlFault(monitor: *control_flow.Monitor) void {
    switch (load(&harness_last_fault_target)) {
        abi.fault.control_phase => monitor.phase = load(&harness_fault_value),
        abi.fault.control_signature => monitor.signature ^= load(&harness_fault_value),
        else => {},
    }
    mirrorMonitor(monitor);
}

// commit: corrupt the active record after validate and before commit so the
// checkpoint commit-or-restart detects it and restores the last good state.
fn applyCommitFault(state: *checkpoint.CheckpointedRecord) void {
    switch (load(&harness_last_fault_target)) {
        abi.fault.active_value => state.active.value = load(&harness_fault_value),
        abi.fault.active_checksum => state.active.checksum ^= load(&harness_fault_value),
        else => {},
    }
}

fn recordControl(status: control_flow.ControlStatus) bool {
    store(&harness_last_control_status, status.code());
    return status.passed();
}

// Runs the full protected workflow once over the pre-initialized working state
// and leaves the observed facts in the harness_last_* globals. The outcome is
// computed by classifyOutcome.
fn runWorkflow() void {
    var monitor = control_flow.Monitor.init();
    var update = recovery_block.SampleUpdate{
        .sample = 0,
        .faults = recovery_block.sample_fault.none,
    };

    mirrorMonitor(&monitor);

    // start -> read_input
    if (!recordControl(monitor.advance(.start, .read_input))) {
        mirrorMonitor(&monitor);
        return;
    }

    // read_input: TMR vote (faults applied to the triplet first).
    store(&harness_stage, abi.stage.after_control_read);
    applyControlFault(&monitor);
    applyTmrFault(&harness_combined_tmr);
    const voted = harness_combined_tmr.read() catch {
        store(&harness_last_tmr_status, abi.status.no_majority);
        return; // no majority -> safe stop
    };
    store(&harness_last_tmr_status, abi.status.ok);
    update.sample = voted;

    // read_input -> compute
    if (!recordControl(monitor.advance(.read_input, .compute))) {
        mirrorMonitor(&monitor);
        return;
    }

    // compute: recovery block over the voted sample.
    store(&harness_stage, abi.stage.after_control_compute);
    const recovery = recovery_block.runWithHooks(
        &harness_combined_record,
        &update,
        recovery_block.samplePrimary,
        applyAfterPrimaryFault,
        recovery_block.sampleAlternate,
        applyAfterAlternateFault,
    );
    store(&harness_last_recovery_status, recovery.status.code());
    store(&harness_last_checkpoint_check, recovery.checkpoint_check.code());
    store(&harness_last_active_check, recovery.primary_check.code());
    if (recovery.status != .primary_accepted and recovery.status != .alternate_accepted) {
        store(&harness_last_value, harness_combined_record.active.value);
        return; // unrecoverable -> safe stop (restored to last good)
    }

    // compute -> validate
    if (!recordControl(monitor.advance(.compute, .validate))) {
        mirrorMonitor(&monitor);
        return;
    }

    // validate: checker acceptance gate.
    store(&harness_last_active_check, harness_combined_record.active.validate().code());

    // validate -> commit
    if (!recordControl(monitor.advance(.validate, .commit))) {
        mirrorMonitor(&monitor);
        return;
    }

    // commit: checkpoint commit-or-restart (faults applied just before).
    applyCommitFault(&harness_combined_record);
    const commit = harness_combined_record.commitOrRestart();
    store(&harness_last_restart_status, commit.status.code());
    store(&harness_last_active_check, commit.active_check.code());
    store(&harness_last_checkpoint_check, commit.checkpoint_check.code());
    store(&harness_last_value, harness_combined_record.active.value);
    if (commit.status == .restore_failed) {
        return; // both copies bad -> safe stop
    }

    // commit -> done
    if (!recordControl(monitor.advance(.commit, .done))) {
        mirrorMonitor(&monitor);
        return;
    }

    if (!recordControl(monitor.finish())) {
        mirrorMonitor(&monitor);
        return;
    }
    mirrorMonitor(&monitor);
}

// Folds the observed facts into a single workflow outcome.
fn classifyOutcome(expected: u32) u32 {
    const corrected =
        load(&harness_last_recovery_status) == abi.recovery.alternate_accepted or
        load(&harness_last_restart_status) == abi.restart.restored or
        harness_combined_tmr.fault_count != 0;

    const recovery_status = load(&harness_last_recovery_status);
    if (load(&harness_last_control_status) != abi.control.ok or
        load(&harness_last_tmr_status) != abi.status.ok or
        load(&harness_last_restart_status) == abi.restart.restore_failed or
        (recovery_status != abi.recovery.primary_accepted and
            recovery_status != abi.recovery.alternate_accepted))
    {
        return abi.outcome.safe_stop;
    }

    if (load(&harness_last_value) == expected) {
        return if (corrected) abi.outcome.recovered else abi.outcome.correct;
    }
    return abi.outcome.sdc;
}

fn validate() void {
    const target = load(&harness_last_fault_target);
    const outcome = load(&harness_last_outcome);
    const pass = if (target == abi.fault.none)
        outcome == abi.outcome.correct
    else
        outcome != abi.outcome.sdc;

    if (pass) {
        store(&harness_passes, load(&harness_passes) +% 1);
    } else {
        store(&harness_failures, load(&harness_failures) +% 1);
    }
}

export fn harness_main() callconv(.c) noreturn {
    store(&harness_stage, abi.stage.boot);

    while (true) {
        const iteration = load(&harness_iteration) +% 1;
        const input = sampleInput(iteration);
        const expected = recovery_block.samplePrimaryValue(input);

        store(&harness_iteration, iteration);
        store(&harness_last_expected, expected);
        store(&harness_last_value, 0);
        store(&harness_last_outcome, abi.outcome.correct);
        store(&harness_last_tmr_status, abi.status.ok);
        store(&harness_last_recovery_status, abi.recovery.primary_accepted);
        store(&harness_last_restart_status, abi.restart.committed);
        store(&harness_last_control_status, abi.control.ok);
        store(&harness_last_active_check, @intFromEnum(checker.CheckStatus.ok));
        store(&harness_last_checkpoint_check, @intFromEnum(checker.CheckStatus.ok));
        store(&harness_last_phase, @intFromEnum(control_flow.Phase.start));
        store(&harness_last_transitions, 0);
        store(&harness_last_fault_target, abi.fault.none);
        harness_combined_tmr = TmrU32.init(input);
        harness_combined_record = checkpoint.CheckpointedRecord.init(sampleRecord(input));

        store(&harness_stage, abi.stage.before_workflow);
        @call(.never_inline, harness_injection_point_before_workflow, .{});

        store(&harness_last_fault_target, load(&harness_fault_target));
        runWorkflow();
        store(&harness_fault_target, abi.fault.none);

        store(&harness_last_outcome, classifyOutcome(expected));

        store(&harness_stage, abi.stage.after_workflow);
        validate();
        @call(.never_inline, harness_injection_point_after_workflow, .{});
    }
}

pub fn panic(msg: []const u8, trace: ?*std.builtin.StackTrace, ra: ?usize) noreturn {
    _ = msg;
    _ = trace;
    _ = ra;
    while (true) {}
}

const abi = @import("abi");
const std = @import("std");

// The baseline harness runs the same workflow as the combined harness, but with
// no fault tolerance at all:
//
//   read_input  a single plain read
//   compute     a single implementation, no acceptance test
//   validate    (none)
//   commit      a plain assignment, no checkpoint
//   whole run   no control-flow monitor
//
// It shares the combined harness's workload (so `expected` matches) and the same
// injected (target, value) faults, applied to the plain equivalents. With
// nothing to mask, detect, or recover, every meaningful fault commits a wrong
// value: the outcome is silent data corruption (abi.outcome.sdc). This is the
// unprotected reference the combined harness is measured against.

export var harness_iteration: u32 = 0;
export var harness_stage: u32 = 0;
export var harness_fault_target: u32 = 0;
export var harness_fault_value: u32 = 0;
export var harness_last_fault_target: u32 = 0;
export var harness_last_expected: u32 = 0;
export var harness_last_value: u32 = 0;
export var harness_last_outcome: u32 = 0;
export var harness_passes: u32 = 0;
export var harness_failures: u32 = 0;

fn load(ptr: *const volatile u32) u32 {
    return ptr.*;
}

fn store(ptr: *volatile u32, value: u32) void {
    ptr.* = value;
}

fn sampleInput(iteration: u32) u32 {
    return 100 + ((iteration *% 41) % 700);
}

// Plain compute, replicating recovery_block.samplePrimaryValue so that the
// baseline and combined harnesses agree on the expected output.
fn computeValue(sample: u32) u32 {
    const reduced = sample % 700;
    return 100 + (((reduced *% 37) + 17) % 700);
}

export fn harness_injection_point_before_workflow() callconv(.c) void {
    asm volatile ("nop // injection_point_before_workflow");
}

export fn harness_injection_point_after_workflow() callconv(.c) void {
    asm volatile ("nop // injection_point_after_workflow");
}

fn runWorkflow(input_seed: u32) void {
    const target = load(&harness_last_fault_target);
    const value = load(&harness_fault_value);
    var input = input_seed;
    var output: u32 = undefined;

    // read_input (unprotected): a corrupted copy silently replaces the input.
    store(&harness_stage, abi.stage.after_control_read);
    if (target == abi.fault.copy_a or target == abi.fault.all_distinct) {
        input = value;
    }

    // control divergence (unprotected): nothing monitors the phase, so a
    // corrupted control path simply skips the compute step.
    if (target == abi.fault.control_phase or target == abi.fault.control_signature) {
        store(&harness_last_value, 0); // stale: compute never ran
        return;
    }

    // compute (unprotected): no acceptance test, no alternate.
    store(&harness_stage, abi.stage.after_control_compute);
    output = computeValue(input);
    if (target == abi.fault.recovery_primary_value) {
        output = value;
    } else if (target == abi.fault.recovery_primary_checksum) {
        output ^= value;
    }

    // commit (unprotected): no checkpoint, no validation gate.
    if (target == abi.fault.active_value) {
        output = value;
    } else if (target == abi.fault.active_checksum) {
        output ^= value;
    }

    store(&harness_last_value, output);
}

fn classifyOutcome(expected: u32) u32 {
    return if (load(&harness_last_value) == expected)
        abi.outcome.correct
    else
        abi.outcome.sdc;
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
        const expected = computeValue(input);

        store(&harness_iteration, iteration);
        store(&harness_last_expected, expected);
        store(&harness_last_value, 0);
        store(&harness_last_outcome, abi.outcome.correct);
        store(&harness_last_fault_target, abi.fault.none);

        store(&harness_stage, abi.stage.before_workflow);
        @call(.never_inline, harness_injection_point_before_workflow, .{});

        store(&harness_last_fault_target, load(&harness_fault_target));
        runWorkflow(input);
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

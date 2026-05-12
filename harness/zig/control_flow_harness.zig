const abi = @import("abi");
const control_flow = @import("control_flow");
const std = @import("std");

comptime {
    std.debug.assert(abi.control.ok == @intFromEnum(control_flow.ControlStatus.ok));
    std.debug.assert(abi.control.invalid_transition == @intFromEnum(control_flow.ControlStatus.invalid_transition));
    std.debug.assert(abi.control.bad_signature == @intFromEnum(control_flow.ControlStatus.bad_signature));
    std.debug.assert(abi.control.unexpected_terminal == @intFromEnum(control_flow.ControlStatus.unexpected_terminal));
}

export var harness_iteration: u32 = 0;
export var harness_stage: u32 = 0;
export var harness_fault_target: u32 = 0;
export var harness_fault_value: u32 = 0;
export var harness_last_expected: u32 = 0;
export var harness_last_value: u32 = 0;
export var harness_last_status: u32 = 0;
export var harness_last_control_status: u32 = 0;
export var harness_last_terminal_status: u32 = 0;
export var harness_last_phase: u32 = 0;
export var harness_last_signature: u32 = 0;
export var harness_last_transitions: u32 = 0;
export var harness_passes: u32 = 0;
export var harness_failures: u32 = 0;
export var harness_last_fault_target: u32 = 0;

fn load(ptr: *const volatile u32) u32 {
    return ptr.*;
}

fn store(ptr: *volatile u32, value: u32) void {
    ptr.* = value;
}

fn pattern(iteration: u32) u32 {
    return 100 + ((iteration *% 41) % 900);
}

fn computeValue(input: u32) u32 {
    return input + 7;
}

export fn harness_injection_point_before_control_flow() callconv(.c) void {
    asm volatile ("nop // injection_point_before_control_flow");
}

export fn harness_injection_point_after_control_flow() callconv(.c) void {
    asm volatile ("nop // injection_point_after_control_flow");
}

fn mirrorMonitor(monitor: *const control_flow.Monitor) void {
    store(&harness_last_phase, monitor.phase);
    store(&harness_last_signature, monitor.signature);
    store(&harness_last_transitions, monitor.transitions);
}

fn applyAfterReadFault(monitor: *control_flow.Monitor) void {
    switch (load(&harness_fault_target)) {
        abi.fault.control_phase => monitor.phase = load(&harness_fault_value),
        abi.fault.control_signature => monitor.signature ^= load(&harness_fault_value),
        else => {},
    }
    mirrorMonitor(monitor);
}

fn recordStatus(status: control_flow.ControlStatus) control_flow.ControlStatus {
    store(&harness_last_control_status, status.code());
    if (!status.passed()) {
        store(&harness_last_status, status.code());
    }
    return status;
}

fn runControlFlow(input: u32) void {
    var monitor = control_flow.Monitor.init();
    var computed: u32 = 0;

    mirrorMonitor(&monitor);

    var status = monitor.advance(.start, .read_input);
    if (!recordStatus(status).passed()) {
        mirrorMonitor(&monitor);
        return;
    }

    store(&harness_stage, abi.stage.after_control_read);
    applyAfterReadFault(&monitor);

    if (load(&harness_fault_target) == abi.fault.control_repeat_read) {
        status = monitor.advance(.start, .read_input);
        _ = recordStatus(status);
        mirrorMonitor(&monitor);
        return;
    }

    if (load(&harness_fault_target) == abi.fault.control_skip_compute) {
        status = monitor.advance(.compute, .validate);
        _ = recordStatus(status);
        mirrorMonitor(&monitor);
        return;
    }

    status = monitor.advance(.read_input, .compute);
    if (!recordStatus(status).passed()) {
        mirrorMonitor(&monitor);
        return;
    }

    computed = computeValue(input);
    store(&harness_stage, abi.stage.after_control_compute);
    mirrorMonitor(&monitor);

    if (load(&harness_fault_target) == abi.fault.control_early_terminal) {
        const terminal_status = monitor.finish();
        store(&harness_last_terminal_status, terminal_status.code());
        store(&harness_last_status, terminal_status.code());
        mirrorMonitor(&monitor);
        return;
    }

    status = monitor.advance(.compute, .validate);
    if (!recordStatus(status).passed()) {
        mirrorMonitor(&monitor);
        return;
    }

    status = monitor.advance(.validate, .commit);
    if (!recordStatus(status).passed()) {
        mirrorMonitor(&monitor);
        return;
    }

    store(&harness_last_value, computed);

    status = monitor.advance(.commit, .done);
    if (!recordStatus(status).passed()) {
        mirrorMonitor(&monitor);
        return;
    }

    const terminal_status = monitor.finish();
    store(&harness_last_terminal_status, terminal_status.code());
    store(&harness_last_status, terminal_status.code());
    mirrorMonitor(&monitor);
}

fn incrementPasses() void {
    store(&harness_passes, load(&harness_passes) +% 1);
}

fn incrementFailures() void {
    store(&harness_failures, load(&harness_failures) +% 1);
}

fn validate(expected: u32) void {
    const target = load(&harness_last_fault_target);
    const status = load(&harness_last_status);
    const control_status = load(&harness_last_control_status);
    const terminal_status = load(&harness_last_terminal_status);
    const phase = load(&harness_last_phase);
    const value = load(&harness_last_value);

    switch (target) {
        abi.fault.control_phase,
        abi.fault.control_skip_compute,
        abi.fault.control_repeat_read,
        => {
            if (status == abi.control.invalid_transition and
                control_status == abi.control.invalid_transition and
                terminal_status == abi.control.ok and
                value == 0)
            {
                incrementPasses();
            } else {
                incrementFailures();
            }
        },
        abi.fault.control_signature => {
            if (status == abi.control.bad_signature and
                control_status == abi.control.bad_signature and
                terminal_status == abi.control.ok and
                phase == @intFromEnum(control_flow.Phase.read_input) and
                value == 0)
            {
                incrementPasses();
            } else {
                incrementFailures();
            }
        },
        abi.fault.control_early_terminal => {
            if (status == abi.control.unexpected_terminal and
                control_status == abi.control.ok and
                terminal_status == abi.control.unexpected_terminal and
                phase == @intFromEnum(control_flow.Phase.compute) and
                value == 0)
            {
                incrementPasses();
            } else {
                incrementFailures();
            }
        },
        else => {
            if (status == abi.control.ok and
                control_status == abi.control.ok and
                terminal_status == abi.control.ok and
                phase == @intFromEnum(control_flow.Phase.done) and
                value == expected)
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
        const input = pattern(iteration);
        const expected = computeValue(input);

        store(&harness_iteration, iteration);
        store(&harness_last_expected, expected);
        store(&harness_last_value, 0);
        store(&harness_last_status, abi.control.ok);
        store(&harness_last_control_status, abi.control.ok);
        store(&harness_last_terminal_status, abi.control.ok);
        store(&harness_last_phase, @intFromEnum(control_flow.Phase.start));
        store(&harness_last_signature, control_flow.phaseSignature(.start));
        store(&harness_last_transitions, 0);
        store(&harness_last_fault_target, abi.fault.none);

        store(&harness_stage, abi.stage.before_control_flow);
        @call(.never_inline, harness_injection_point_before_control_flow, .{});

        store(&harness_last_fault_target, load(&harness_fault_target));
        runControlFlow(input);
        store(&harness_fault_target, abi.fault.none);

        store(&harness_stage, abi.stage.after_control_flow);
        validate(expected);
        @call(.never_inline, harness_injection_point_after_control_flow, .{});
    }
}

pub fn panic(msg: []const u8, trace: ?*std.builtin.StackTrace, ra: ?usize) noreturn {
    _ = msg;
    _ = trace;
    _ = ra;
    while (true) {}
}

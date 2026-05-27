const control_flow = @import("control_flow");
const fuzz = @import("fuzz_abi.zig");
const std = @import("std");

export var harness_fuzz_control_phase: u32 = 0;
export var harness_fuzz_control_signature: u32 = 0;
export var harness_fuzz_control_transitions: u32 = 0;

fn sampleInput(rng: *u64) u32 {
    return 100 + (fuzz.randomU32(rng) % 900);
}

fn computeValue(input: u32) u32 {
    return input + 7;
}

fn loadMonitor() control_flow.Monitor {
    return .{
        .phase = fuzz.load32(&harness_fuzz_control_phase),
        .signature = fuzz.load32(&harness_fuzz_control_signature),
        .transitions = fuzz.load32(&harness_fuzz_control_transitions),
    };
}

fn mirrorMonitor(monitor: *const control_flow.Monitor) void {
    fuzz.store32(&harness_fuzz_control_phase, monitor.phase);
    fuzz.store32(&harness_fuzz_control_signature, monitor.signature);
    fuzz.store32(&harness_fuzz_control_transitions, monitor.transitions);
}

fn recordStatus(status: control_flow.ControlStatus) bool {
    if (!status.passed()) {
        fuzz.store32(&fuzz.harness_detected, 1);
        fuzz.store32(&fuzz.harness_error_code, status.code());
        return false;
    }
    return true;
}

fn advance(expected_from: control_flow.Phase, next_phase: control_flow.Phase) bool {
    var monitor = loadMonitor();
    const status = monitor.advance(expected_from, next_phase);
    mirrorMonitor(&monitor);
    return recordStatus(status);
}

fn runControlFlow(input: u32) void {
    if (!advance(.start, .read_input)) {
        fuzz.store32(&fuzz.harness_safe_state, 1);
        return;
    }
    if (!advance(.read_input, .compute)) {
        fuzz.store32(&fuzz.harness_safe_state, 1);
        return;
    }

    const computed = computeValue(input);

    if (!advance(.compute, .validate)) {
        fuzz.store32(&fuzz.harness_safe_state, 1);
        return;
    }
    if (!advance(.validate, .commit)) {
        fuzz.store32(&fuzz.harness_safe_state, 1);
        return;
    }

    fuzz.store32(&fuzz.harness_output, computed);

    if (!advance(.commit, .done)) {
        return;
    }

    var monitor = loadMonitor();
    const status = monitor.finish();
    mirrorMonitor(&monitor);
    _ = recordStatus(status);
}

export fn harness_main() callconv(.c) noreturn {
    var rng = fuzz.seedState();
    const input = sampleInput(&rng);
    const expected = computeValue(input);
    var monitor = control_flow.Monitor.init();

    fuzz.store32(&fuzz.harness_expected, expected);
    mirrorMonitor(&monitor);

    fuzz.openFaultWindow();
    runControlFlow(input);
    fuzz.closeFaultWindow();

    if (fuzz.load32(&fuzz.harness_detected) != 0 and
        fuzz.load32(&fuzz.harness_output) == expected)
    {
        fuzz.store32(&fuzz.harness_corrected, 1);
    }

    fuzz.complete();
}

pub fn panic(msg: []const u8, trace: ?*std.builtin.StackTrace, ra: ?usize) noreturn {
    _ = msg;
    _ = trace;
    _ = ra;
    while (true) {}
}

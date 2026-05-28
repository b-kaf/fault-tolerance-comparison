const control_flow = @import("control_flow");
const fuzz = @import("fuzz_abi.zig");

export var harness_fuzz_control_monitor: control_flow.Monitor = undefined;

fn sampleInput(rng: *u64) u32 {
    return 100 + (fuzz.randomU32(rng) % 900);
}

fn computeValue(input: u32) u32 {
    return input + 7;
}

fn recordStatus(status: control_flow.ControlStatus) bool {
    if (!status.passed()) {
        fuzz.store32(&fuzz.harness_detected, 1);
        fuzz.store32(&fuzz.harness_error_code, status.code());
        return false;
    }
    return true;
}

fn advance(
    monitor: *control_flow.Monitor,
    expected_from: control_flow.Phase,
    next_phase: control_flow.Phase,
) bool {
    const status = monitor.advance(expected_from, next_phase);
    return recordStatus(status);
}

fn runControlFlow(monitor: *control_flow.Monitor, input: u32) void {
    if (!advance(monitor, .start, .read_input)) {
        fuzz.store32(&fuzz.harness_safe_state, 1);
        return;
    }
    if (!advance(monitor, .read_input, .compute)) {
        fuzz.store32(&fuzz.harness_safe_state, 1);
        return;
    }

    const computed = computeValue(input);

    if (!advance(monitor, .compute, .validate)) {
        fuzz.store32(&fuzz.harness_safe_state, 1);
        return;
    }
    if (!advance(monitor, .validate, .commit)) {
        fuzz.store32(&fuzz.harness_safe_state, 1);
        return;
    }

    fuzz.store32(&fuzz.harness_output, computed);

    if (!advance(monitor, .commit, .done)) {
        return;
    }

    const status = monitor.finish();
    _ = recordStatus(status);
}

export fn harness_main() callconv(.c) noreturn {
    var rng = fuzz.seedState();
    const input = sampleInput(&rng);
    const expected = computeValue(input);

    fuzz.store32(&fuzz.harness_expected, expected);
    harness_fuzz_control_monitor = control_flow.Monitor.init();

    fuzz.openFaultWindow();
    // never_inline keeps loads of harness_fuzz_control_monitor from being hoisted across the window.
    @call(.never_inline, runControlFlow, .{ &harness_fuzz_control_monitor, input });
    fuzz.closeFaultWindow();

    if (fuzz.load32(&fuzz.harness_detected) != 0 and
        fuzz.load32(&fuzz.harness_output) == expected)
    {
        fuzz.store32(&fuzz.harness_corrected, 1);
    }

    fuzz.complete();
}

pub const panic = fuzz.panic;

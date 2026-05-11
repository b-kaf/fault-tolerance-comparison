const tmr = @import("tmr");
const abi = @import("abi");
const std = @import("std");

const TmrU32 = tmr.Tmr(u32);

export var harness_iteration: u32 = 0;
export var harness_stage: u32 = 0;
export var harness_fault_target: u32 = 0;
export var harness_fault_value: u32 = 0;
export var harness_last_expected: u32 = 0;
export var harness_last_value: u32 = 0;
export var harness_last_status: u32 = 0;
export var harness_passes: u32 = 0;
export var harness_failures: u32 = 0;
export var harness_last_fault_target: u32 = 0;
export var harness_zig_tmr_a: u32 = 0;
export var harness_zig_tmr_b: u32 = 0;
export var harness_zig_tmr_c: u32 = 0;
export var harness_zig_tmr_fault_count: u32 = 0;

fn load(ptr: *const volatile u32) u32 {
    return ptr.*;
}

fn store(ptr: *volatile u32, value: u32) void {
    ptr.* = value;
}

fn pattern(iteration: u32) u32 {
    return 0x5a5a0000 ^ (iteration *% 2654435761);
}

fn mirrorState(state: *const TmrU32) void {
    store(&harness_zig_tmr_a, state.a);
    store(&harness_zig_tmr_b, state.b);
    store(&harness_zig_tmr_c, state.c);
    store(&harness_zig_tmr_fault_count, state.fault_count);
}

export fn harness_injection_point_after_init() callconv(.c) void {
    asm volatile ("nop // injection_point_after_init");
}

export fn harness_injection_point_after_read() callconv(.c) void {
    asm volatile ("nop // injection_point_after_read");
}

fn applyPendingFault(state: *TmrU32) void {
    const target = load(&harness_fault_target);
    const value = load(&harness_fault_value);

    store(&harness_last_fault_target, target);

    switch (target) {
        abi.fault.copy_a => state.injectFaultA(value),
        abi.fault.all_distinct => state.injectAll(
            value,
            value ^ 0x11111111,
            value ^ 0x22222222,
        ),
        else => {},
    }

    store(&harness_fault_target, abi.fault.none);
    mirrorState(state);
}

fn validate(expected: u32, tmr_status: u32, value: u32) void {
    const injected = load(&harness_last_fault_target);
    const expect_no_majority = injected == abi.fault.all_distinct;

    if (expect_no_majority) {
        if (tmr_status == abi.status.no_majority) {
            store(&harness_passes, load(&harness_passes) +% 1);
        } else {
            store(&harness_failures, load(&harness_failures) +% 1);
        }
        return;
    }

    if (tmr_status == abi.status.ok and value == expected) {
        store(&harness_passes, load(&harness_passes) +% 1);
    } else {
        store(&harness_failures, load(&harness_failures) +% 1);
    }
}

export fn harness_main() callconv(.c) noreturn {
    store(&harness_stage, abi.stage.boot);

    while (true) {
        const iteration = load(&harness_iteration) +% 1;
        const expected = pattern(iteration);
        var state = TmrU32.init(expected);

        store(&harness_iteration, iteration);
        store(&harness_last_expected, expected);
        store(&harness_last_value, 0);
        store(&harness_last_status, abi.status.ok);
        store(&harness_last_fault_target, abi.fault.none);
        mirrorState(&state);

        store(&harness_stage, abi.stage.after_init);
        @call(.never_inline, harness_injection_point_after_init, .{});

        applyPendingFault(&state);

        store(&harness_stage, abi.stage.before_read);
        if (state.read()) |value| {
            store(&harness_last_value, value);
            store(&harness_last_status, abi.status.ok);
        } else |err| switch (err) {
            tmr.TmrError.NoMajority => {
                store(&harness_last_status, abi.status.no_majority);
            },
        }
        mirrorState(&state);

        store(&harness_stage, abi.stage.after_read);
        validate(expected, load(&harness_last_status), load(&harness_last_value));
        @call(.never_inline, harness_injection_point_after_read, .{});
    }
}

pub fn panic(msg: []const u8, trace: ?*std.builtin.StackTrace, ra: ?usize) noreturn {
    _ = msg;
    _ = trace;
    _ = ra;
    while (true) {}
}

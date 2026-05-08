const tmr = @import("tmr");
const std = @import("std");

const HARNESS_STAGE_BOOT: u32 = 0;
const HARNESS_STAGE_AFTER_INIT: u32 = 1;
const HARNESS_STAGE_BEFORE_READ: u32 = 2;
const HARNESS_STAGE_AFTER_READ: u32 = 3;

const HARNESS_FAULT_NONE: u32 = 0;
const HARNESS_FAULT_COPY_A: u32 = 1;
const HARNESS_FAULT_ALL_DISTINCT: u32 = 2;

const HARNESS_STATUS_OK: u32 = 0;
const HARNESS_STATUS_NO_MAJORITY: u32 = 1;

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

fn load(ptr: *volatile const u32) u32 {
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
    asm volatile ("nop");
}

export fn harness_injection_point_after_read() callconv(.c) void {
    asm volatile ("nop");
}

fn applyPendingFault(state: *TmrU32) void {
    const target = load(&harness_fault_target);
    const value = load(&harness_fault_value);

    store(&harness_last_fault_target, target);

    switch (target) {
        HARNESS_FAULT_COPY_A => state.injectFaultA(value),
        HARNESS_FAULT_ALL_DISTINCT => state.injectAll(
            value,
            value ^ 0x11111111,
            value ^ 0x22222222,
        ),
        else => {},
    }

    store(&harness_fault_target, HARNESS_FAULT_NONE);
    mirrorState(state);
}

fn validate(expected: u32, status: u32, value: u32) void {
    const injected = load(&harness_last_fault_target);
    const expect_no_majority = injected == HARNESS_FAULT_ALL_DISTINCT;

    if (expect_no_majority) {
        if (status == HARNESS_STATUS_NO_MAJORITY) {
            store(&harness_passes, load(&harness_passes) +% 1);
        } else {
            store(&harness_failures, load(&harness_failures) +% 1);
        }
        return;
    }

    if (status == HARNESS_STATUS_OK and value == expected) {
        store(&harness_passes, load(&harness_passes) +% 1);
    } else {
        store(&harness_failures, load(&harness_failures) +% 1);
    }
}

export fn harness_main() callconv(.c) noreturn {
    store(&harness_stage, HARNESS_STAGE_BOOT);

    while (true) {
        const iteration = load(&harness_iteration) +% 1;
        const expected = pattern(iteration);
        var state = TmrU32.init(expected);

        store(&harness_iteration, iteration);
        store(&harness_last_expected, expected);
        store(&harness_last_value, 0);
        store(&harness_last_status, HARNESS_STATUS_OK);
        store(&harness_last_fault_target, HARNESS_FAULT_NONE);
        mirrorState(&state);

        store(&harness_stage, HARNESS_STAGE_AFTER_INIT);
        harness_injection_point_after_init();

        applyPendingFault(&state);

        store(&harness_stage, HARNESS_STAGE_BEFORE_READ);
        if (state.read()) |value| {
            store(&harness_last_value, value);
            store(&harness_last_status, HARNESS_STATUS_OK);
        } else |err| switch (err) {
            tmr.TmrError.NoMajority => {
                store(&harness_last_status, HARNESS_STATUS_NO_MAJORITY);
            },
        }
        mirrorState(&state);

        store(&harness_stage, HARNESS_STAGE_AFTER_READ);
        validate(expected, load(&harness_last_status), load(&harness_last_value));
        harness_injection_point_after_read();
    }
}

pub fn panic(msg: []const u8, trace: ?*std.builtin.StackTrace, ra: ?usize) noreturn {
    _ = msg;
    _ = trace;
    _ = ra;
    while (true) {}
}

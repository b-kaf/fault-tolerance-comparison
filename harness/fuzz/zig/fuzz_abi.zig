const std = @import("std");

pub export var harness_trial_seed: u64 = 0;
pub export var harness_done: u32 = 0;
pub export var harness_detected: u32 = 0;
pub export var harness_corrected: u32 = 0;
pub export var harness_safe_state: u32 = 0;
pub export var harness_output: u32 = 0;
pub export var harness_expected: u32 = 0;
pub export var harness_error_code: u32 = 0;
pub export var harness_fault_window_open: u32 = 0;

pub fn load32(ptr: *const volatile u32) u32 {
    return ptr.*;
}

pub fn store32(ptr: *volatile u32, value: u32) void {
    ptr.* = value;
}

pub fn load64(ptr: *const volatile u64) u64 {
    return ptr.*;
}

pub fn seedState() u64 {
    const seed = load64(&harness_trial_seed);
    return if (seed == 0) 0x9e3779b97f4a7c15 else seed;
}

pub fn splitmix64Next(state: *u64) u64 {
    state.* +%= 0x9e3779b97f4a7c15;
    var z = state.*;
    z = (z ^ (z >> 30)) *% 0xbf58476d1ce4e5b9;
    z = (z ^ (z >> 27)) *% 0x94d049bb133111eb;
    return z ^ (z >> 31);
}

pub fn randomU32(state: *u64) u32 {
    return @intCast(splitmix64Next(state) >> 32);
}

pub fn openFaultWindow() void {
    store32(&harness_fault_window_open, 1);
}

pub fn closeFaultWindow() void {
    store32(&harness_fault_window_open, 0);
}

pub fn complete() noreturn {
    store32(&harness_done, 1);
    while (true) {
        asm volatile ("nop");
    }
}

pub fn panic(msg: []const u8, trace: ?*std.builtin.StackTrace, ra: ?usize) noreturn {
    _ = msg;
    _ = trace;
    _ = ra;
    while (true) {}
}

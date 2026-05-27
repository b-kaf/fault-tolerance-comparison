const fuzz = @import("fuzz_abi.zig");
const std = @import("std");
const tmr = @import("tmr");

const TmrU32 = tmr.Tmr(u32);

export var harness_fuzz_tmr_a: u32 = 0;
export var harness_fuzz_tmr_b: u32 = 0;
export var harness_fuzz_tmr_c: u32 = 0;
export var harness_fuzz_tmr_fault_count: u32 = 0;

fn sampleValue(rng: *u64) u32 {
    return 0x5a5a0000 ^ fuzz.randomU32(rng);
}

fn loadState() TmrU32 {
    return .{
        .a = fuzz.load32(&harness_fuzz_tmr_a),
        .b = fuzz.load32(&harness_fuzz_tmr_b),
        .c = fuzz.load32(&harness_fuzz_tmr_c),
        .fault_count = fuzz.load32(&harness_fuzz_tmr_fault_count),
    };
}

fn mirrorState(state: *const TmrU32) void {
    fuzz.store32(&harness_fuzz_tmr_a, state.a);
    fuzz.store32(&harness_fuzz_tmr_b, state.b);
    fuzz.store32(&harness_fuzz_tmr_c, state.c);
    fuzz.store32(&harness_fuzz_tmr_fault_count, state.fault_count);
}

export fn harness_main() callconv(.c) noreturn {
    var rng = fuzz.seedState();
    const expected = sampleValue(&rng);
    var state = TmrU32.init(expected);

    fuzz.store32(&fuzz.harness_expected, expected);
    mirrorState(&state);

    fuzz.openFaultWindow();
    state = loadState();
    if (state.read()) |value| {
        fuzz.store32(&fuzz.harness_output, value);
        if (state.fault_count != 0) {
            fuzz.store32(&fuzz.harness_detected, 1);
            if (value == expected) {
                fuzz.store32(&fuzz.harness_corrected, 1);
            }
        }
    } else |err| switch (err) {
        tmr.TmrError.NoMajority => {
            fuzz.store32(&fuzz.harness_detected, 1);
            fuzz.store32(&fuzz.harness_safe_state, 1);
            fuzz.store32(&fuzz.harness_error_code, 1);
        },
    }
    mirrorState(&state);
    fuzz.closeFaultWindow();

    fuzz.complete();
}

pub fn panic(msg: []const u8, trace: ?*std.builtin.StackTrace, ra: ?usize) noreturn {
    _ = msg;
    _ = trace;
    _ = ra;
    while (true) {}
}

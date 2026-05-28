const fuzz = @import("fuzz_abi.zig");
const tmr = @import("tmr");

const TmrU32 = tmr.Tmr(u32);

export var harness_fuzz_tmr_state: TmrU32 = undefined;

fn sampleValue(rng: *u64) u32 {
    return 0x5a5a0000 ^ fuzz.randomU32(rng);
}

export fn harness_main() callconv(.c) noreturn {
    var rng = fuzz.seedState();
    const expected = sampleValue(&rng);

    fuzz.store32(&fuzz.harness_expected, expected);
    harness_fuzz_tmr_state = TmrU32.init(expected);

    fuzz.openFaultWindow();
    // never_inline keeps loads of harness_fuzz_tmr_state from being hoisted across the window.
    const read_result = @call(.never_inline, TmrU32.read, .{&harness_fuzz_tmr_state});
    fuzz.closeFaultWindow();

    if (read_result) |value| {
        fuzz.store32(&fuzz.harness_output, value);
        if (harness_fuzz_tmr_state.fault_count != 0) {
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

    fuzz.complete();
}

pub const panic = fuzz.panic;

const fuzz = @import("fuzz_abi.zig");
const tmr = @import("tmr");
const checker = @import("checker");
const checkpoint = @import("checkpoint");
const recovery_block = @import("recovery_block");
const control_flow = @import("control_flow");

// Single-shot combined fuzz harness: runs the full protected workflow once
// (TMR read -> recovery-block compute -> checker validate -> checkpoint commit,
// all under a control-flow monitor) with the fault window open. The QEMU plugin
// injects one register or RAM bit flip during the window; the workflow then
// masks, corrects, or fail-safes it, or — a finding — lets it through as SDC.
// The live technique state is exported as harness_fuzz_* so ram-bitflip can
// target it.

const TmrU32 = tmr.Tmr(u32);

export var harness_fuzz_combined_tmr: TmrU32 = undefined;
export var harness_fuzz_combined_record: checkpoint.CheckpointedRecord = undefined;
export var harness_fuzz_combined_monitor: control_flow.Monitor = undefined;

fn sampleInput(rng: *u64) u32 {
    return 100 + (fuzz.randomU32(rng) % 700);
}

fn sampleRecord(value: u32) checker.CheckedRecord {
    return checker.CheckedRecord.init(.sample, value, 0, 1000, 6, 16);
}

fn guard(status: control_flow.ControlStatus) bool {
    if (!status.passed()) {
        fuzz.store32(&fuzz.harness_detected, 1);
        fuzz.store32(&fuzz.harness_safe_state, 1);
        fuzz.store32(&fuzz.harness_error_code, status.code());
        return false;
    }
    return true;
}

fn runWorkflow() void {
    const monitor = &harness_fuzz_combined_monitor;
    const record = &harness_fuzz_combined_record;
    const triplet = &harness_fuzz_combined_tmr;

    // start -> read_input
    if (!guard(monitor.advance(.start, .read_input))) return;

    // read_input: TMR vote.
    const voted = triplet.read() catch {
        fuzz.store32(&fuzz.harness_detected, 1);
        fuzz.store32(&fuzz.harness_safe_state, 1);
        fuzz.store32(&fuzz.harness_error_code, 1);
        return;
    };
    if (triplet.fault_count != 0) {
        fuzz.store32(&fuzz.harness_detected, 1); // a copy was flipped, masked by the vote
    }
    const update = recovery_block.SampleUpdate{
        .sample = voted,
        .faults = recovery_block.sample_fault.none,
    };

    // read_input -> compute
    if (!guard(monitor.advance(.read_input, .compute))) return;

    // compute: recovery block.
    const recovery = recovery_block.runSampleUpdate(record, update);
    if (recovery.status != .primary_accepted) {
        fuzz.store32(&fuzz.harness_detected, 1);
        fuzz.store32(&fuzz.harness_error_code, recovery.status.code());
    }
    if (recovery.status != .primary_accepted and recovery.status != .alternate_accepted) {
        fuzz.store32(&fuzz.harness_safe_state, 1);
        return;
    }

    // compute -> validate -> commit
    if (!guard(monitor.advance(.compute, .validate))) return;
    if (!guard(monitor.advance(.validate, .commit))) return;

    // commit: checkpoint commit-or-restart.
    const commit = record.commitOrRestart();
    if (commit.status != .committed) {
        fuzz.store32(&fuzz.harness_detected, 1);
        fuzz.store32(&fuzz.harness_error_code, commit.status.code());
    }
    if (commit.status == .restore_failed) {
        fuzz.store32(&fuzz.harness_safe_state, 1);
        return;
    }

    // commit -> done
    if (!guard(monitor.advance(.commit, .done))) return;
    _ = guard(monitor.finish());
}

export fn harness_main() callconv(.c) noreturn {
    var rng = fuzz.seedState();
    const input = sampleInput(&rng);
    const expected = recovery_block.samplePrimaryValue(input);

    fuzz.store32(&fuzz.harness_expected, expected);
    harness_fuzz_combined_monitor = control_flow.Monitor.init();
    harness_fuzz_combined_tmr = TmrU32.init(input);
    harness_fuzz_combined_record = checkpoint.CheckpointedRecord.init(sampleRecord(input));

    fuzz.openFaultWindow();
    // never_inline keeps loads of the harness_fuzz_* state from being hoisted across the window.
    @call(.never_inline, runWorkflow, .{});
    fuzz.closeFaultWindow();

    fuzz.store32(&fuzz.harness_output, harness_fuzz_combined_record.active.value);
    if (fuzz.load32(&fuzz.harness_detected) != 0 and
        fuzz.load32(&fuzz.harness_output) == expected)
    {
        fuzz.store32(&fuzz.harness_corrected, 1);
    }

    fuzz.complete();
}

pub const panic = fuzz.panic;

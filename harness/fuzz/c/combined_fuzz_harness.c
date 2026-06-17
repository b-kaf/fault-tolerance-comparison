#include <stdint.h>

#include "fuzz_common.h"
#include "../../common/harness_abi.h"
#include "../../../c/tmr/tmr.h"
#include "../../../c/checker/checker.h"
#include "../../../c/checkpoint/checkpoint.h"
#include "../../../c/recovery_block/recovery_block.h"
#include "../../../c/control_flow/control_flow.h"

/* Single-shot combined fuzz harness: runs the full protected workflow once
 * (TMR read -> recovery-block compute -> checker validate -> checkpoint commit,
 * all under a control-flow monitor) with the fault window open. The QEMU plugin
 * injects one register or RAM bit flip during the window; the workflow then
 * masks, corrects, or fail-safes it, or — a finding — lets it through as SDC.
 * The live technique state is exported as harness_fuzz_* so ram-bitflip can
 * target it. */

_Static_assert((int)TMR_OK == HARNESS_STATUS_OK,
    "tmr_status_t::TMR_OK must match HARNESS_STATUS_OK");
_Static_assert((int)CHECKPOINT_RESTART_COMMITTED == HARNESS_RESTART_COMMITTED,
    "checkpoint_restart_status_t::CHECKPOINT_RESTART_COMMITTED must match HARNESS_RESTART_COMMITTED");
_Static_assert((int)RECOVERY_BLOCK_PRIMARY_ACCEPTED == HARNESS_RECOVERY_PRIMARY_ACCEPTED,
    "recovery_block_status_t::RECOVERY_BLOCK_PRIMARY_ACCEPTED must match HARNESS_RECOVERY_PRIMARY_ACCEPTED");
_Static_assert((int)CONTROL_FLOW_OK == HARNESS_CONTROL_OK,
    "control_flow_status_t::CONTROL_FLOW_OK must match HARNESS_CONTROL_OK");

volatile tmr_int_t harness_fuzz_combined_tmr;
volatile checkpoint_record_t harness_fuzz_combined_record;
volatile control_flow_monitor_t harness_fuzz_combined_monitor;

static uint32_t sample_input(uint64_t *rng) {
    return 100u + (harness_random_u32(rng) % 700u);
}

static checker_record_t sample_record(uint32_t value) {
    return checker_record_init(
        CHECKER_TAG_SAMPLE,
        value,
        0u,
        1000u,
        6u,
        16u);
}

static control_flow_status_t guard(control_flow_status_t status) {
    if (!control_flow_passed(status)) {
        harness_detected = 1u;
        harness_safe_state = 1u;
        harness_error_code = (uint32_t)status;
    }
    return status;
}

__attribute__((noinline))
static void run_workflow(void) {
    control_flow_monitor_t *monitor =
        (control_flow_monitor_t *)&harness_fuzz_combined_monitor;
    checkpoint_record_t *record =
        (checkpoint_record_t *)&harness_fuzz_combined_record;
    tmr_int_t *triplet = (tmr_int_t *)&harness_fuzz_combined_tmr;
    recovery_block_sample_update_t update;
    recovery_block_result_t recovery;
    checkpoint_restart_result_t commit;
    int voted = 0;

    /* start -> read_input */
    if (!control_flow_passed(guard(control_flow_monitor_advance(
            monitor, CONTROL_FLOW_PHASE_START, CONTROL_FLOW_PHASE_READ_INPUT)))) {
        return;
    }

    /* read_input: TMR vote. */
    if (tmr_int_read(triplet, &voted) != TMR_OK) {
        harness_detected = 1u;
        harness_safe_state = 1u;
        harness_error_code = HARNESS_STATUS_NO_MAJORITY;
        return;
    }
    if (triplet->fault_count != 0u) {
        harness_detected = 1u; /* a copy was flipped but the vote masked it */
    }
    update.sample = (uint32_t)voted;
    update.faults = RECOVERY_BLOCK_SAMPLE_FAULT_NONE;

    /* read_input -> compute */
    if (!control_flow_passed(guard(control_flow_monitor_advance(
            monitor, CONTROL_FLOW_PHASE_READ_INPUT, CONTROL_FLOW_PHASE_COMPUTE)))) {
        return;
    }

    /* compute: recovery block. */
    recovery = recovery_block_run(
        record,
        recovery_block_sample_primary,
        recovery_block_sample_alternate,
        &update);
    if (recovery.status != RECOVERY_BLOCK_PRIMARY_ACCEPTED) {
        harness_detected = 1u;
        harness_error_code = (uint32_t)recovery.status;
    }
    if (recovery.status != RECOVERY_BLOCK_PRIMARY_ACCEPTED &&
        recovery.status != RECOVERY_BLOCK_ALTERNATE_ACCEPTED) {
        harness_safe_state = 1u;
        return;
    }

    /* compute -> validate -> commit */
    if (!control_flow_passed(guard(control_flow_monitor_advance(
            monitor, CONTROL_FLOW_PHASE_COMPUTE, CONTROL_FLOW_PHASE_VALIDATE)))) {
        return;
    }
    if (!control_flow_passed(guard(control_flow_monitor_advance(
            monitor, CONTROL_FLOW_PHASE_VALIDATE, CONTROL_FLOW_PHASE_COMMIT)))) {
        return;
    }

    /* commit: checkpoint commit-or-restart. */
    commit = checkpoint_record_commit_or_restart(record);
    if (commit.status != CHECKPOINT_RESTART_COMMITTED) {
        harness_detected = 1u;
        harness_error_code = (uint32_t)commit.status;
    }
    if (commit.status == CHECKPOINT_RESTART_RESTORE_FAILED) {
        harness_safe_state = 1u;
        return;
    }

    /* commit -> done */
    if (!control_flow_passed(guard(control_flow_monitor_advance(
            monitor, CONTROL_FLOW_PHASE_COMMIT, CONTROL_FLOW_PHASE_DONE)))) {
        return;
    }
    (void)guard(control_flow_monitor_finish(monitor));
}

void harness_main(void) {
    uint64_t rng = harness_seed_state();
    const uint32_t input = sample_input(&rng);
    const uint32_t expected = recovery_block_sample_primary_value(input);

    harness_expected = expected;
    harness_fuzz_combined_monitor = control_flow_monitor_init();
    harness_fuzz_combined_tmr = tmr_int_init((int)input);
    harness_fuzz_combined_record = checkpoint_record_init(sample_record(input));

    harness_open_fault_window();
    run_workflow();
    harness_close_fault_window();

    harness_output = harness_fuzz_combined_record.active.value;
    if (harness_detected != 0u && harness_output == harness_expected) {
        harness_corrected = 1u;
    }

    harness_finish();
}

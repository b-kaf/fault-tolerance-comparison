#include <stdint.h>

#include "harness_abi.h"
#include "../../../c/tmr/tmr.h"
#include "../../../c/checker/checker.h"
#include "../../../c/checkpoint/checkpoint.h"
#include "../../../c/recovery_block/recovery_block.h"
#include "../../../c/control_flow/control_flow.h"

/* The combined harness runs one workflow that chains every technique:
 *
 *   start -> read_input -> compute -> validate -> commit -> done
 *
 *   read_input  TMR triplet, majority vote
 *   compute     recovery block (primary -> acceptance test -> alternate)
 *   validate    checker acceptance gate
 *   commit      checkpoint commit-or-restart
 *   whole run   control-flow signature monitor wraps every transition
 *
 * A single inject point (harness_injection_point_before_workflow) sets the
 * (target, value) pair; the workflow applies each fault at its natural phase,
 * exactly as the standalone harnesses do. The final outcome is classified into
 * HARNESS_OUTCOME_* and a pass means the protected workflow avoided silent data
 * corruption. The baseline harness runs the identical workload unprotected. */

_Static_assert((int)TMR_OK == HARNESS_STATUS_OK,
    "tmr_status_t::TMR_OK must match HARNESS_STATUS_OK");
_Static_assert((int)TMR_ERR_NO_MAJORITY == HARNESS_STATUS_NO_MAJORITY,
    "tmr_status_t::TMR_ERR_NO_MAJORITY must match HARNESS_STATUS_NO_MAJORITY");
_Static_assert((int)CHECKPOINT_RESTART_COMMITTED == HARNESS_RESTART_COMMITTED,
    "checkpoint_restart_status_t::CHECKPOINT_RESTART_COMMITTED must match HARNESS_RESTART_COMMITTED");
_Static_assert((int)CHECKPOINT_RESTART_RESTORED == HARNESS_RESTART_RESTORED,
    "checkpoint_restart_status_t::CHECKPOINT_RESTART_RESTORED must match HARNESS_RESTART_RESTORED");
_Static_assert((int)CHECKPOINT_RESTART_RESTORE_FAILED == HARNESS_RESTART_RESTORE_FAILED,
    "checkpoint_restart_status_t::CHECKPOINT_RESTART_RESTORE_FAILED must match HARNESS_RESTART_RESTORE_FAILED");
_Static_assert((int)RECOVERY_BLOCK_PRIMARY_ACCEPTED == HARNESS_RECOVERY_PRIMARY_ACCEPTED,
    "recovery_block_status_t::RECOVERY_BLOCK_PRIMARY_ACCEPTED must match HARNESS_RECOVERY_PRIMARY_ACCEPTED");
_Static_assert((int)RECOVERY_BLOCK_ALTERNATE_ACCEPTED == HARNESS_RECOVERY_ALTERNATE_ACCEPTED,
    "recovery_block_status_t::RECOVERY_BLOCK_ALTERNATE_ACCEPTED must match HARNESS_RECOVERY_ALTERNATE_ACCEPTED");
_Static_assert((int)CONTROL_FLOW_OK == HARNESS_CONTROL_OK,
    "control_flow_status_t::CONTROL_FLOW_OK must match HARNESS_CONTROL_OK");
_Static_assert((int)CONTROL_FLOW_ERR_INVALID_TRANSITION == HARNESS_CONTROL_INVALID_TRANSITION,
    "control_flow_status_t::CONTROL_FLOW_ERR_INVALID_TRANSITION must match HARNESS_CONTROL_INVALID_TRANSITION");
_Static_assert((int)CONTROL_FLOW_ERR_BAD_SIGNATURE == HARNESS_CONTROL_BAD_SIGNATURE,
    "control_flow_status_t::CONTROL_FLOW_ERR_BAD_SIGNATURE must match HARNESS_CONTROL_BAD_SIGNATURE");

volatile uint32_t harness_iteration;
volatile uint32_t harness_stage;
volatile uint32_t harness_fault_target;
volatile uint32_t harness_fault_value;
volatile uint32_t harness_last_fault_target;
volatile uint32_t harness_last_expected;
volatile uint32_t harness_last_value;
volatile uint32_t harness_last_outcome;
volatile uint32_t harness_last_tmr_status;
volatile uint32_t harness_last_recovery_status;
volatile uint32_t harness_last_restart_status;
volatile uint32_t harness_last_control_status;
volatile uint32_t harness_last_active_check;
volatile uint32_t harness_last_checkpoint_check;
volatile uint32_t harness_last_phase;
volatile uint32_t harness_last_transitions;
volatile uint32_t harness_passes;
volatile uint32_t harness_failures;
volatile tmr_int_t harness_c_combined_tmr;
volatile checkpoint_record_t harness_c_combined_record;

static uint32_t sample_input(uint32_t iteration) {
    return 100u + ((iteration * 41u) % 700u);
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

__attribute__((used, noinline))
void harness_injection_point_before_workflow(void) {
    __asm__ volatile("nop");
}

__attribute__((used, noinline))
void harness_injection_point_after_workflow(void) {
    __asm__ volatile("nop");
}

static void mirror_monitor(const control_flow_monitor_t *monitor) {
    harness_last_phase = monitor->phase;
    harness_last_transitions = monitor->transitions;
}

/* read_input: corrupt the TMR triplet before the majority vote. */
static void apply_tmr_fault(tmr_int_t *triplet) {
    const int value = (int)harness_fault_value;

    switch (harness_last_fault_target) {
    case HARNESS_FAULT_COPY_A:
        tmr_int_inject_fault_a(triplet, value);
        break;
    case HARNESS_FAULT_ALL_DISTINCT:
        tmr_int_inject_all(
            triplet,
            value,
            value ^ 0x11111111,
            value ^ 0x22222222);
        break;
    default:
        break;
    }
}

/* compute: corrupt the primary result so the acceptance test rejects it and
 * the recovery block falls through to the alternate. */
static void apply_after_primary_fault(checkpoint_record_t *state, void *context) {
    (void)context;

    harness_stage = HARNESS_STAGE_AFTER_PRIMARY;

    switch (harness_last_fault_target) {
    case HARNESS_FAULT_RECOVERY_PRIMARY_VALUE:
        state->active.value = harness_fault_value;
        break;
    case HARNESS_FAULT_RECOVERY_PRIMARY_CHECKSUM:
        state->active.checksum ^= harness_fault_value;
        break;
    default:
        break;
    }
}

static void apply_after_alternate_fault(checkpoint_record_t *state, void *context) {
    (void)state;
    (void)context;

    harness_stage = HARNESS_STAGE_AFTER_ALTERNATE;
}

/* control: corrupt the monitor between read_input and compute. */
static void apply_control_fault(control_flow_monitor_t *monitor) {
    switch (harness_last_fault_target) {
    case HARNESS_FAULT_CONTROL_PHASE:
        monitor->phase = harness_fault_value;
        break;
    case HARNESS_FAULT_CONTROL_SIGNATURE:
        monitor->signature ^= harness_fault_value;
        break;
    default:
        break;
    }
    mirror_monitor(monitor);
}

/* commit: corrupt the active record after validate and before commit so the
 * checkpoint commit-or-restart detects it and restores the last good state. */
static void apply_commit_fault(checkpoint_record_t *state) {
    switch (harness_last_fault_target) {
    case HARNESS_FAULT_ACTIVE_VALUE:
        state->active.value = harness_fault_value;
        break;
    case HARNESS_FAULT_ACTIVE_CHECKSUM:
        state->active.checksum ^= harness_fault_value;
        break;
    default:
        break;
    }
}

static int record_control(control_flow_status_t status) {
    harness_last_control_status = (uint32_t)status;
    return control_flow_passed(status);
}

/* Runs the full protected workflow once and leaves the observed facts in the
 * harness_last_* globals. harness_last_outcome is set by classify_outcome. */
static void run_workflow(uint32_t iteration) {
    control_flow_monitor_t monitor = control_flow_monitor_init();
    checkpoint_record_t *record =
        (checkpoint_record_t *)&harness_c_combined_record;
    tmr_int_t *triplet = (tmr_int_t *)&harness_c_combined_tmr;
    recovery_block_sample_update_t update;
    recovery_block_result_t recovery;
    checkpoint_restart_result_t commit;
    control_flow_status_t cf;
    tmr_status_t tmr_status;
    int voted = 0;
    uint32_t sample;

    mirror_monitor(&monitor);

    /* start -> read_input */
    cf = control_flow_monitor_advance(
        &monitor, CONTROL_FLOW_PHASE_START, CONTROL_FLOW_PHASE_READ_INPUT);
    if (!record_control(cf)) {
        mirror_monitor(&monitor);
        return;
    }

    /* read_input: TMR vote (faults applied to the triplet first). */
    harness_stage = HARNESS_STAGE_AFTER_CONTROL_READ;
    apply_control_fault(&monitor);
    apply_tmr_fault(triplet);
    tmr_status = tmr_int_read(triplet, &voted);
    harness_last_tmr_status = (uint32_t)tmr_status;
    if (tmr_status != TMR_OK) {
        return; /* no majority -> safe stop */
    }
    sample = (uint32_t)voted;

    /* read_input -> compute */
    cf = control_flow_monitor_advance(
        &monitor, CONTROL_FLOW_PHASE_READ_INPUT, CONTROL_FLOW_PHASE_COMPUTE);
    if (!record_control(cf)) {
        mirror_monitor(&monitor);
        return;
    }

    /* compute: recovery block over the voted sample. */
    harness_stage = HARNESS_STAGE_AFTER_CONTROL_COMPUTE;
    update.sample = sample;
    update.faults = RECOVERY_BLOCK_SAMPLE_FAULT_NONE;
    recovery = recovery_block_run_with_hooks(
        record,
        recovery_block_sample_primary,
        apply_after_primary_fault,
        recovery_block_sample_alternate,
        apply_after_alternate_fault,
        &update);
    harness_last_recovery_status = recovery.status;
    harness_last_checkpoint_check = recovery.checkpoint_check;
    harness_last_active_check = recovery.primary_check;
    if (recovery.status != RECOVERY_BLOCK_PRIMARY_ACCEPTED &&
        recovery.status != RECOVERY_BLOCK_ALTERNATE_ACCEPTED) {
        harness_last_value = record->active.value;
        return; /* unrecoverable -> safe stop (restored to last good) */
    }

    /* compute -> validate */
    cf = control_flow_monitor_advance(
        &monitor, CONTROL_FLOW_PHASE_COMPUTE, CONTROL_FLOW_PHASE_VALIDATE);
    if (!record_control(cf)) {
        mirror_monitor(&monitor);
        return;
    }

    /* validate: checker acceptance gate. */
    harness_last_active_check = checker_record_validate(&record->active);

    /* validate -> commit */
    cf = control_flow_monitor_advance(
        &monitor, CONTROL_FLOW_PHASE_VALIDATE, CONTROL_FLOW_PHASE_COMMIT);
    if (!record_control(cf)) {
        mirror_monitor(&monitor);
        return;
    }

    /* commit: checkpoint commit-or-restart (faults applied just before). */
    apply_commit_fault(record);
    commit = checkpoint_record_commit_or_restart(record);
    harness_last_restart_status = commit.status;
    harness_last_active_check = commit.active_check;
    harness_last_checkpoint_check = commit.checkpoint_check;
    harness_last_value = record->active.value;
    if (commit.status == CHECKPOINT_RESTART_RESTORE_FAILED) {
        return; /* both copies bad -> safe stop */
    }

    /* commit -> done */
    cf = control_flow_monitor_advance(
        &monitor, CONTROL_FLOW_PHASE_COMMIT, CONTROL_FLOW_PHASE_DONE);
    if (!record_control(cf)) {
        mirror_monitor(&monitor);
        return;
    }

    if (!record_control(control_flow_monitor_finish(&monitor))) {
        mirror_monitor(&monitor);
        return;
    }
    mirror_monitor(&monitor);

    (void)iteration;
}

/* Folds the observed facts into a single workflow outcome. */
static uint32_t classify_outcome(uint32_t expected) {
    const uint32_t corrected =
        harness_last_recovery_status == HARNESS_RECOVERY_ALTERNATE_ACCEPTED ||
        harness_last_restart_status == HARNESS_RESTART_RESTORED ||
        harness_c_combined_tmr.fault_count != 0u;

    /* A detected error that stopped the workflow before commit is fail-safe. */
    if (harness_last_control_status != HARNESS_CONTROL_OK ||
        harness_last_tmr_status != HARNESS_STATUS_OK ||
        harness_last_restart_status == HARNESS_RESTART_RESTORE_FAILED ||
        (harness_last_recovery_status != HARNESS_RECOVERY_PRIMARY_ACCEPTED &&
         harness_last_recovery_status != HARNESS_RECOVERY_ALTERNATE_ACCEPTED)) {
        return HARNESS_OUTCOME_SAFE_STOP;
    }

    if (harness_last_value == expected) {
        return corrected ? HARNESS_OUTCOME_RECOVERED : HARNESS_OUTCOME_CORRECT;
    }
    return HARNESS_OUTCOME_SDC;
}

static void validate(void) {
    const uint32_t target = harness_last_fault_target;
    const uint32_t outcome = harness_last_outcome;
    int pass;

    if (target == HARNESS_FAULT_NONE) {
        pass = outcome == HARNESS_OUTCOME_CORRECT;
    } else {
        pass = outcome != HARNESS_OUTCOME_SDC;
    }

    if (pass) {
        harness_passes += 1u;
    } else {
        harness_failures += 1u;
    }
}

void harness_main(void) {
    harness_stage = HARNESS_STAGE_BOOT;

    for (;;) {
        const uint32_t iteration = harness_iteration + 1u;
        const uint32_t input = sample_input(iteration);
        const uint32_t expected = recovery_block_sample_primary_value(input);

        harness_iteration = iteration;
        harness_last_expected = expected;
        harness_last_value = 0u;
        harness_last_outcome = HARNESS_OUTCOME_CORRECT;
        harness_last_tmr_status = HARNESS_STATUS_OK;
        harness_last_recovery_status = HARNESS_RECOVERY_PRIMARY_ACCEPTED;
        harness_last_restart_status = HARNESS_RESTART_COMMITTED;
        harness_last_control_status = HARNESS_CONTROL_OK;
        harness_last_active_check = CHECKER_OK;
        harness_last_checkpoint_check = CHECKER_OK;
        harness_last_phase = CONTROL_FLOW_PHASE_START;
        harness_last_transitions = 0u;
        harness_last_fault_target = HARNESS_FAULT_NONE;
        harness_c_combined_tmr = tmr_int_init((int)input);
        harness_c_combined_record = checkpoint_record_init(sample_record(input));

        harness_stage = HARNESS_STAGE_BEFORE_WORKFLOW;
        harness_injection_point_before_workflow();

        harness_last_fault_target = harness_fault_target;
        run_workflow(iteration);
        harness_fault_target = HARNESS_FAULT_NONE;

        harness_last_outcome = classify_outcome(expected);

        harness_stage = HARNESS_STAGE_AFTER_WORKFLOW;
        validate();
        harness_injection_point_after_workflow();
    }
}

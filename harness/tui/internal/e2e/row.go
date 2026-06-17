package e2e

import (
	"github.com/b-kaf/fault-tolerance-comparison/harness/tui/internal/gdbmi"
	"github.com/b-kaf/fault-tolerance-comparison/harness/tui/internal/result"
)

// reader accumulates the first read error so a row builder can read a whole
// field set without checking after every call, then inspect err once.
type reader struct {
	gdb *gdbmi.Client
	err error
}

func (r *reader) u32(name string) uint32 {
	if r.err != nil {
		return 0
	}
	value, err := r.gdb.ReadU32(name)
	if err != nil {
		r.err = err
	}
	return value
}

// The four row builders mirror the per-technique row dicts in main.py. Field
// names and the values read are the contract; result formatting derives the
// labels and deltas. fault_value is the chosen value masked to 32 bits, like
// `fault_value & 0xFFFFFFFF` in Python.

func tmrRow(gdb *gdbmi.Client, campaign, implementation string, iteration, expected uint32, f fault) (result.Row, error) {
	r := reader{gdb: gdb}
	row := result.Row{
		"technique":      "tmr",
		"implementation": implementation,
		"campaign":       campaign,
		"iteration":      iteration,
		"stage":          r.u32("harness_stage"),
		"fault_target":   r.u32("harness_last_fault_target"),
		"fault_value":    f.value,
		"expected":       expected,
		"status":         r.u32("harness_last_status"),
		"value":          r.u32("harness_last_value"),
		"passes":         r.u32("harness_passes"),
		"failures":       r.u32("harness_failures"),
	}
	return row, r.err
}

func checkpointRow(gdb *gdbmi.Client, campaign, implementation string, iteration uint32, f fault) (result.Row, error) {
	r := reader{gdb: gdb}
	row := result.Row{
		"technique":        "checkpoint",
		"implementation":   implementation,
		"campaign":         campaign,
		"iteration":        iteration,
		"stage":            r.u32("harness_stage"),
		"fault_target":     r.u32("harness_last_fault_target"),
		"fault_value":      f.value,
		"initial_value":    r.u32("harness_last_initial_value"),
		"expected":         r.u32("harness_last_expected"),
		"status":           r.u32("harness_last_status"),
		"restart_status":   r.u32("harness_last_restart_status"),
		"active_check":     r.u32("harness_last_active_check"),
		"checkpoint_check": r.u32("harness_last_checkpoint_check"),
		"value":            r.u32("harness_last_value"),
		"active_value":     r.u32("harness_last_active_value"),
		"checkpoint_value": r.u32("harness_last_checkpoint_value"),
		"passes":           r.u32("harness_passes"),
		"failures":         r.u32("harness_failures"),
	}
	return row, r.err
}

func recoveryBlockRow(gdb *gdbmi.Client, campaign, implementation string, iteration uint32, f fault) (result.Row, error) {
	r := reader{gdb: gdb}
	row := result.Row{
		"technique":        "recovery-block",
		"implementation":   implementation,
		"campaign":         campaign,
		"iteration":        iteration,
		"stage":            r.u32("harness_stage"),
		"fault_target":     r.u32("harness_last_fault_target"),
		"fault_value":      f.value,
		"initial_value":    r.u32("harness_last_initial_value"),
		"expected":         r.u32("harness_last_expected"),
		"status":           r.u32("harness_last_status"),
		"recovery_status":  r.u32("harness_last_recovery_status"),
		"checkpoint_check": r.u32("harness_last_checkpoint_check"),
		"primary_check":    r.u32("harness_last_primary_check"),
		"restore_check":    r.u32("harness_last_restore_check"),
		"alternate_check":  r.u32("harness_last_alternate_check"),
		"value":            r.u32("harness_last_value"),
		"active_value":     r.u32("harness_last_active_value"),
		"checkpoint_value": r.u32("harness_last_checkpoint_value"),
		"passes":           r.u32("harness_passes"),
		"failures":         r.u32("harness_failures"),
	}
	return row, r.err
}

func combinedRow(gdb *gdbmi.Client, campaign, implementation string, iteration uint32, f fault) (result.Row, error) {
	r := reader{gdb: gdb}
	row := result.Row{
		"technique":        "combined",
		"implementation":   implementation,
		"campaign":         campaign,
		"iteration":        iteration,
		"stage":            r.u32("harness_stage"),
		"fault_target":     r.u32("harness_last_fault_target"),
		"fault_value":      f.value,
		"expected":         r.u32("harness_last_expected"),
		"value":            r.u32("harness_last_value"),
		"outcome":          r.u32("harness_last_outcome"),
		"tmr_status":       r.u32("harness_last_tmr_status"),
		"recovery_status":  r.u32("harness_last_recovery_status"),
		"restart_status":   r.u32("harness_last_restart_status"),
		"control_status":   r.u32("harness_last_control_status"),
		"active_check":     r.u32("harness_last_active_check"),
		"checkpoint_check": r.u32("harness_last_checkpoint_check"),
		"phase":            r.u32("harness_last_phase"),
		"transitions":      r.u32("harness_last_transitions"),
		"passes":           r.u32("harness_passes"),
		"failures":         r.u32("harness_failures"),
	}
	return row, r.err
}

func baselineRow(gdb *gdbmi.Client, campaign, implementation string, iteration uint32, f fault) (result.Row, error) {
	r := reader{gdb: gdb}
	row := result.Row{
		"technique":      "baseline",
		"implementation": implementation,
		"campaign":       campaign,
		"iteration":      iteration,
		"stage":          r.u32("harness_stage"),
		"fault_target":   r.u32("harness_last_fault_target"),
		"fault_value":    f.value,
		"expected":       r.u32("harness_last_expected"),
		"value":          r.u32("harness_last_value"),
		"outcome":        r.u32("harness_last_outcome"),
		"passes":         r.u32("harness_passes"),
		"failures":       r.u32("harness_failures"),
	}
	return row, r.err
}

func controlFlowRow(gdb *gdbmi.Client, campaign, implementation string, iteration uint32, f fault) (result.Row, error) {
	r := reader{gdb: gdb}
	row := result.Row{
		"technique":       "control-flow",
		"implementation":  implementation,
		"campaign":        campaign,
		"iteration":       iteration,
		"stage":           r.u32("harness_stage"),
		"fault_target":    r.u32("harness_last_fault_target"),
		"fault_value":     f.value,
		"expected":        r.u32("harness_last_expected"),
		"status":          r.u32("harness_last_status"),
		"control_status":  r.u32("harness_last_control_status"),
		"terminal_status": r.u32("harness_last_terminal_status"),
		"phase":           r.u32("harness_last_phase"),
		"signature":       r.u32("harness_last_signature"),
		"transitions":     r.u32("harness_last_transitions"),
		"value":           r.u32("harness_last_value"),
		"passes":          r.u32("harness_passes"),
		"failures":        r.u32("harness_failures"),
	}
	return row, r.err
}

// Package result ports harness_shared/result_format.py. Column names and
// order are the contract with the existing CSVs — do not reorder.
package result

var stageNames = map[int64]string{
	0:  "boot",
	1:  "after_init",
	2:  "before_read",
	3:  "after_read",
	4:  "after_checkpoint",
	5:  "after_mutation",
	6:  "before_commit",
	7:  "after_commit",
	8:  "before_recovery",
	9:  "after_primary",
	10: "after_alternate",
	11: "after_recovery",
	12: "before_control_flow",
	13: "after_control_read",
	14: "after_control_compute",
	15: "after_control_flow",
	16: "before_workflow",
	17: "after_workflow",
}

var faultNames = map[int64]string{
	0:  "none",
	1:  "copy_a",
	2:  "all_distinct",
	10: "active_value",
	11: "active_length",
	12: "active_checksum",
	13: "checkpoint_value",
	14: "checkpoint_checksum",
	15: "active_value_and_checkpoint_checksum",
	20: "recovery_primary_value",
	21: "recovery_primary_checksum",
	22: "recovery_primary_value_and_alternate_checksum",
	23: "recovery_primary_value_and_checkpoint_checksum",
	30: "control_phase",
	31: "control_signature",
	32: "control_skip_compute",
	33: "control_repeat_read",
	34: "control_early_terminal",
}

var tmrStatusNames = map[int64]string{
	0: "ok",
	1: "no_majority",
}

var restartStatusNames = map[int64]string{
	0: "committed",
	1: "restored",
	2: "restore_failed",
}

var recoveryStatusNames = map[int64]string{
	0: "primary_accepted",
	1: "alternate_accepted",
	2: "unrecoverable",
	3: "checkpoint_failed",
	4: "restore_failed",
}

var controlStatusNames = map[int64]string{
	0: "ok",
	1: "invalid_transition",
	2: "bad_signature",
	3: "unexpected_terminal",
}

var checkStatusNames = map[int64]string{
	0: "ok",
	1: "below_min",
	2: "above_max",
	3: "invalid_length",
	4: "invalid_checksum",
	5: "inconsistent_fields",
	6: "invalid_tag",
}

var phaseNames = map[int64]string{
	0: "start",
	1: "read_input",
	2: "compute",
	3: "validate",
	4: "commit",
	5: "done",
}

var outcomeNames = map[int64]string{
	0: "correct",
	1: "recovered",
	2: "safe_stop",
	3: "sdc",
}

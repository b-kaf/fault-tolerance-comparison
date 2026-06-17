// Package e2e ports harness/e2e/injector: GDB-driven fault-injection
// campaigns. The fault constants, per-technique campaign tables, mixed-order
// rotations, and the technique/campaign validation matrix all mirror main.py.
package e2e

import "slices"

// Fault target constants, mirroring the FAULT_* values in main.py.
const (
	faultNone                                      = 0
	faultCopyA                                     = 1
	faultAllDistinct                               = 2
	faultActiveValue                               = 10
	faultActiveLength                              = 11
	faultActiveChecksum                            = 12
	faultCheckpointValue                           = 13
	faultCheckpointChecksum                        = 14
	faultActiveValueAndCheckpointChecksum          = 15
	faultRecoveryPrimaryValue                      = 20
	faultRecoveryPrimaryChecksum                   = 21
	faultRecoveryPrimaryValueAndAlternateChecksum  = 22
	faultRecoveryPrimaryValueAndCheckpointChecksum = 23
	faultControlPhase                              = 30
	faultControlSignature                          = 31
	faultControlSkipCompute                        = 32
	faultControlRepeatRead                         = 33
	faultControlEarlyTerminal                      = 34

	controlPhaseCommit = 4
)

// fault is a (target, value) pair chosen for an iteration.
type fault struct {
	target uint32
	value  uint32
}

// tmrCampaigns: TMR fault values depend on the iteration's expected pattern,
// so each entry is a function of expected.
var tmrCampaigns = map[string]func(expected uint32) fault{
	"none":         func(uint32) fault { return fault{faultNone, 0} },
	"single-a":     func(exp uint32) fault { return fault{faultCopyA, exp ^ 0xFFFFFFFF} },
	"all-distinct": func(exp uint32) fault { return fault{faultAllDistinct, exp ^ 0x13579BDF} },
}

var tmrMixedOrder = []string{"none", "single-a", "all-distinct"}

// checkpointCampaigns are independent of iteration/expected, so static.
var checkpointCampaigns = map[string]fault{
	"none":                             {faultNone, 0},
	"checkpoint-clean-run":             {faultNone, 0},
	"checkpoint-active-value-fault":    {faultActiveValue, 0xFFFFFFFF},
	"checkpoint-active-length-fault":   {faultActiveLength, 0xFFFFFFFF},
	"checkpoint-active-checksum-fault": {faultActiveChecksum, 0x10},
	"checkpoint-saved-checksum-fault":  {faultCheckpointChecksum, 0x10},
	"checkpoint-double-fault":          {faultActiveValueAndCheckpointChecksum, 0xFFFFFFFF},
}

var checkpointMixedOrder = []string{
	"none",
	"checkpoint-active-value-fault",
	"checkpoint-active-length-fault",
	"checkpoint-active-checksum-fault",
	"checkpoint-saved-checksum-fault",
	"checkpoint-double-fault",
}

var recoveryBlockCampaigns = map[string]fault{
	"none":                        {faultNone, 0},
	"recovery-clean-primary":      {faultNone, 0},
	"recovery-primary-range":      {faultRecoveryPrimaryValue, 0xFFFFFFFF},
	"recovery-primary-checksum":   {faultRecoveryPrimaryChecksum, 0x10},
	"recovery-alternate-checksum": {faultRecoveryPrimaryValueAndAlternateChecksum, 0xFFFFFFFF},
	"recovery-restore-failure":    {faultRecoveryPrimaryValueAndCheckpointChecksum, 0xFFFFFFFF},
}

var recoveryBlockMixedOrder = []string{
	"none",
	"recovery-primary-range",
	"recovery-primary-checksum",
	"recovery-alternate-checksum",
	"recovery-restore-failure",
}

var controlFlowCampaigns = map[string]fault{
	"none":                      {faultNone, 0},
	"control-clean-path":        {faultNone, 0},
	"control-phase-corrupt":     {faultControlPhase, controlPhaseCommit},
	"control-signature-corrupt": {faultControlSignature, 0x10},
	"control-skip-compute":      {faultControlSkipCompute, 0},
	"control-repeat-read":       {faultControlRepeatRead, 0},
	"control-early-terminal":    {faultControlEarlyTerminal, 0},
}

var controlFlowMixedOrder = []string{
	"none",
	"control-phase-corrupt",
	"control-signature-corrupt",
	"control-skip-compute",
	"control-repeat-read",
	"control-early-terminal",
}

// workflowCampaigns drive both the combined (all techniques) and baseline (no
// techniques) harnesses with the same injected faults — one representative per
// technique — so the two images can be compared row-for-row under an identical
// fault sequence. The fault targets are the existing per-technique IDs; the
// workflow firmware applies each at its natural phase.
var workflowCampaigns = map[string]fault{
	"none":                         {faultNone, 0},
	"workflow-clean-run":           {faultNone, 0},
	"workflow-tmr-single":          {faultCopyA, 0xFFFFFFFF},
	"workflow-tmr-distinct":        {faultAllDistinct, 0xFFFFFFFF},
	"workflow-checkpoint-value":    {faultActiveValue, 0xFFFFFFFF},
	"workflow-checkpoint-checksum": {faultActiveChecksum, 0x10},
	"workflow-recovery-value":      {faultRecoveryPrimaryValue, 0xFFFFFFFF},
	"workflow-recovery-checksum":   {faultRecoveryPrimaryChecksum, 0x10},
	"workflow-control-phase":       {faultControlPhase, controlPhaseCommit},
	"workflow-control-signature":   {faultControlSignature, 0x10},
}

var workflowMixedOrder = []string{
	"none",
	"workflow-tmr-single",
	"workflow-tmr-distinct",
	"workflow-checkpoint-value",
	"workflow-checkpoint-checksum",
	"workflow-recovery-value",
	"workflow-recovery-checksum",
	"workflow-control-phase",
	"workflow-control-signature",
}

// These mirror *_SAMPLE_CHOICES / *_CHOICES (used by the validation matrix):
// the prefixed campaign names in main.py dict-literal order, followed by the
// mixed alias. Listed explicitly because Go maps have no insertion order.
var (
	checkpointSampleChoices = []string{
		"checkpoint-clean-run",
		"checkpoint-active-value-fault",
		"checkpoint-active-length-fault",
		"checkpoint-active-checksum-fault",
		"checkpoint-saved-checksum-fault",
		"checkpoint-double-fault",
		"checkpoint-mixed-faults",
	}
	recoveryBlockChoices = []string{
		"recovery-clean-primary",
		"recovery-primary-range",
		"recovery-primary-checksum",
		"recovery-alternate-checksum",
		"recovery-restore-failure",
		"recovery-mixed-faults",
	}
	controlFlowChoices = []string{
		"control-clean-path",
		"control-phase-corrupt",
		"control-signature-corrupt",
		"control-skip-compute",
		"control-repeat-read",
		"control-early-terminal",
		"control-mixed-faults",
	}
	// workflowChoices are shared by the combined and baseline techniques.
	workflowChoices = []string{
		"workflow-clean-run",
		"workflow-tmr-single",
		"workflow-tmr-distinct",
		"workflow-checkpoint-value",
		"workflow-checkpoint-checksum",
		"workflow-recovery-value",
		"workflow-recovery-checksum",
		"workflow-control-phase",
		"workflow-control-signature",
		"workflow-mixed-faults",
	}
)

// Campaign validation matrix, mirroring resolve_config. Returns "" when the
// technique/campaign pairing is valid, or an error message otherwise.
func ValidateTechniqueCampaign(technique, campaign string) string {
	inCheckpoint := slices.Contains(checkpointSampleChoices, campaign)
	inRecovery := slices.Contains(recoveryBlockChoices, campaign)
	inControl := slices.Contains(controlFlowChoices, campaign)
	inWorkflow := slices.Contains(workflowChoices, campaign)
	isTMROnly := campaign == "single-a" || campaign == "all-distinct"

	const workflowOnly = "workflow-* campaigns require --technique combined or baseline"

	switch technique {
	case "tmr":
		if inCheckpoint || inRecovery || inControl || inWorkflow {
			return "checkpoint-* campaigns require --technique checkpoint; " +
				"recovery-* campaigns require --technique recovery-block; " +
				"control-* campaigns require --technique control-flow; " +
				workflowOnly
		}
	case "checkpoint":
		if isTMROnly || inRecovery || inControl || inWorkflow {
			return "single-a/all-distinct campaigns require --technique tmr; " +
				"recovery-* campaigns require --technique recovery-block; " +
				"control-* campaigns require --technique control-flow; " +
				workflowOnly
		}
	case "recovery-block":
		if isTMROnly || inCheckpoint || inControl || inWorkflow {
			return "single-a/all-distinct campaigns require --technique tmr; " +
				"checkpoint-* campaigns require --technique checkpoint; " +
				"control-* campaigns require --technique control-flow; " +
				workflowOnly
		}
	case "control-flow":
		if isTMROnly || inCheckpoint || inRecovery || inWorkflow {
			return "single-a/all-distinct campaigns require --technique tmr; " +
				"checkpoint-* campaigns require --technique checkpoint; " +
				"recovery-* campaigns require --technique recovery-block; " +
				workflowOnly
		}
	case "combined", "baseline":
		if isTMROnly || inCheckpoint || inRecovery || inControl {
			return "single-a/all-distinct campaigns require --technique tmr; " +
				"checkpoint-* campaigns require --technique checkpoint; " +
				"recovery-* campaigns require --technique recovery-block; " +
				"control-* campaigns require --technique control-flow"
		}
	}
	return ""
}

// CampaignChoices is the full accepted set for the CLI/TUI, mirroring the
// --campaign choices tuple.
func CampaignChoices() []string {
	choices := []string{"mixed", "none", "single-a", "all-distinct"}
	choices = append(choices, checkpointSampleChoices...)
	choices = append(choices, recoveryBlockChoices...)
	choices = append(choices, controlFlowChoices...)
	choices = append(choices, workflowChoices...)
	return choices
}

// CampaignsForTechnique returns the campaigns valid for a technique, used by
// the TUI to reload the campaign select when the technique changes. "mixed"
// and "none" apply to every technique (per the validation matrix); the
// technique-specific named campaigns follow.
func CampaignsForTechnique(technique string) []string {
	base := []string{"mixed", "none"}
	switch technique {
	case "tmr":
		return append(base, "single-a", "all-distinct")
	case "checkpoint":
		return append(base, checkpointSampleChoices...)
	case "recovery-block":
		return append(base, recoveryBlockChoices...)
	case "control-flow":
		return append(base, controlFlowChoices...)
	case "combined", "baseline":
		return append(base, workflowChoices...)
	}
	return base
}

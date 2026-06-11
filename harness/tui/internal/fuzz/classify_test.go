package fuzz

import (
	"maps"
	"testing"
)

// Mirrors classification_test.py. base() is the all-clean trial; tests
// override what they need.
func base(overrides map[string]string) map[string]string {
	facts := map[string]string{
		"harness_done":                 "1",
		"harness_detected":             "0",
		"harness_corrected":            "0",
		"harness_safe_state":           "0",
		"harness_output":               "7",
		"harness_expected":             "7",
		"injected":                     "1",
		"instruction_budget_exhausted": "0",
	}
	maps.Copy(facts, overrides)
	return facts
}

type classifyCase struct {
	name              string
	facts             map[string]string
	processStatus     string
	timeout           bool
	requiresInjection bool
	want              string
}

func TestClassify(t *testing.T) {
	cases := []classifyCase{
		// Ports of classification_test.py.
		{name: "timeout_maps_to_hang",
			facts: map[string]string{}, timeout: true, want: "hang"},
		{name: "budget_maps_to_hang",
			facts: base(map[string]string{"instruction_budget_exhausted": "1"}), want: "hang"},
		{name: "abnormal_exit_before_done_maps_to_crash",
			facts: map[string]string{}, processStatus: "exit:1", want: "crash"},
		{name: "wrong_output_without_detection_maps_to_sdc",
			facts: base(map[string]string{"harness_output": "8"}), want: "sdc"},
		{name: "detected_valid_recovery_maps_to_corrected",
			facts: base(map[string]string{"harness_detected": "1", "harness_corrected": "1"}),
			want:  "corrected"},
		{name: "detected_non_commit_maps_to_fail_safe",
			facts: base(map[string]string{
				"harness_detected": "1", "harness_safe_state": "1", "harness_output": "0",
			}),
			want: "fail_safe"},
		{name: "matching_output_without_detection_maps_to_passed",
			facts: base(nil), want: "passed"},
		{name: "missing_required_fact_maps_to_invalid",
			facts: deleteFact(base(nil), "harness_expected"), want: "invalid_trial"},
		{name: "correction_without_detection_is_invalid",
			facts: base(map[string]string{"harness_corrected": "1"}), want: "invalid_trial"},
		{name: "required_injection_without_injection_is_invalid",
			facts: base(map[string]string{"injected": "0"}), requiresInjection: true,
			want: "invalid_trial"},

		// Additional edge interactions not covered by the Python suite.
		{name: "safe_state_without_detection_is_invalid",
			facts: base(map[string]string{"harness_safe_state": "1"}), want: "invalid_trial"},
		{name: "correction_with_wrong_output_is_invalid",
			facts: base(map[string]string{
				"harness_detected": "1", "harness_corrected": "1", "harness_output": "8",
			}),
			want: "invalid_trial"},
		{name: "detected_without_correction_wrong_output_maps_to_detected",
			facts: base(map[string]string{"harness_detected": "1", "harness_output": "8"}),
			want:  "detected"},
		{name: "done_zero_after_clean_exit_is_invalid",
			facts: base(map[string]string{"harness_done": "0"}), want: "invalid_trial"},
		{name: "timeout_wins_over_crash",
			facts: map[string]string{}, processStatus: "exit:1", timeout: true, want: "hang"},
		{name: "hex_facts_parse_with_base_zero",
			facts: base(map[string]string{"harness_output": "0x7", "harness_expected": "7"}),
			want:  "passed"},
		{name: "malformed_required_fact_is_invalid",
			facts: base(map[string]string{"harness_output": "garbage"}), want: "invalid_trial"},
	}

	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			status := tc.processStatus
			if status == "" {
				status = "completed"
			}
			got := Classify(ClassificationInput{
				Facts:             tc.facts,
				ProcessStatus:     status,
				Timeout:           tc.timeout,
				RequiresInjection: tc.requiresInjection,
			})
			if got != tc.want {
				t.Errorf("Classify() = %q, want %q", got, tc.want)
			}
		})
	}
}

func deleteFact(facts map[string]string, name string) map[string]string {
	delete(facts, name)
	return facts
}

// Reference seeds computed by the Python implementation:
// hashlib.blake2b(payload, digest_size=8, person=b"ft-single").
func TestDeriveTrialSeedMatchesPython(t *testing.T) {
	cases := []struct {
		campaignSeed   uint64
		trialID        int
		technique      string
		implementation string
		campaign       string
		want           uint64
	}{
		{0xC0DEC0DE, 0, "tmr", "zig", "reg-bitflip", 0x3D96BB347EB3FF87},
		{0xC0DEC0DE, 1, "tmr", "zig", "reg-bitflip", 0xFB3606AD98431FBF},
		{0xC0DEC0DE, 19, "control-flow", "c", "ram-bitflip", 0xB836B27AFE6AD76C},
		{0x0, 0, "checkpoint", "c", "none", 0x23BF6884077942C8},
		{0xFFFFFFFFFFFFFFFF, 7, "recovery-block", "zig", "ram-bitflip", 0xE6DDEFABCD254402},
	}
	for _, tc := range cases {
		got := DeriveTrialSeed(tc.campaignSeed, tc.trialID, tc.technique, tc.implementation, tc.campaign)
		if got != tc.want {
			t.Errorf("DeriveTrialSeed(0x%x, %d, %s, %s, %s) = 0x%016X, want 0x%016X",
				tc.campaignSeed, tc.trialID, tc.technique, tc.implementation, tc.campaign,
				got, tc.want)
		}
	}
}

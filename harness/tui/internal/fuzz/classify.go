package fuzz

import (
	"strconv"
	"strings"
)

// ClassificationInput mirrors classification.ClassificationInput. Facts are
// the key=value pairs from the trial's raw result file.
type ClassificationInput struct {
	Facts             map[string]string
	ProcessStatus     string
	Timeout           bool
	RequiresInjection bool
}

var requiredFacts = []string{
	"harness_done",
	"harness_detected",
	"harness_corrected",
	"harness_safe_state",
	"harness_output",
	"harness_expected",
}

// Classify is the 9-way trial classifier from classification.classify_trial.
// One deliberate divergence: a required fact that is present but not a valid
// integer classifies the trial as invalid_trial, where Python would raise
// and abort the whole campaign.
func Classify(in ClassificationInput) string {
	facts := in.Facts

	if in.Timeout || intFact(facts, "instruction_budget_exhausted", 0) != 0 {
		return "hang"
	}

	done := intFact(facts, "harness_done", 0)
	if strings.HasPrefix(in.ProcessStatus, "exit:") && done != 1 {
		return "crash"
	}

	for _, field := range requiredFacts {
		value, present := facts[field]
		if !present {
			return "invalid_trial"
		}
		if value != "" {
			if _, err := strconv.ParseInt(value, 0, 64); err != nil {
				return "invalid_trial"
			}
		}
	}
	if done != 1 {
		return "invalid_trial"
	}

	detected := intFact(facts, "harness_detected", 0)
	corrected := intFact(facts, "harness_corrected", 0)
	safeState := intFact(facts, "harness_safe_state", 0)
	output := intFact(facts, "harness_output", 0)
	expected := intFact(facts, "harness_expected", 0)
	injected := intFact(facts, "injected", 0)

	if corrected != 0 && detected == 0 {
		return "invalid_trial"
	}
	if safeState != 0 && detected == 0 {
		return "invalid_trial"
	}
	if corrected != 0 && output != expected {
		return "invalid_trial"
	}
	if in.RequiresInjection && injected == 0 {
		return "invalid_trial"
	}

	if safeState != 0 && detected != 0 {
		return "fail_safe"
	}
	if detected != 0 && output == expected {
		return "corrected"
	}
	if detected != 0 {
		return "detected"
	}
	if output != expected {
		return "sdc"
	}
	return "passed"
}

// intFact mirrors classification.int_field: missing or empty returns the
// default; values parse with base-0 semantics. Unparseable values return the
// default (see the divergence note on Classify).
func intFact(facts map[string]string, name string, def int64) int64 {
	value, ok := facts[name]
	if !ok || value == "" {
		return def
	}
	n, err := strconv.ParseInt(value, 0, 64)
	if err != nil {
		return def
	}
	return n
}

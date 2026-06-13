package fuzz

import "testing"

func TestFormatCounts(t *testing.T) {
	if got := FormatCounts(nil, " "); got != "" {
		t.Errorf("empty = %q, want \"\"", got)
	}
	counts := map[string]int{"sdc": 2, "passed": 5, "crash": 1}
	if got := FormatCounts(counts, " "); got != "crash=1 passed=5 sdc=2" {
		t.Errorf("space-joined = %q", got)
	}
	if got := FormatCounts(counts, ", "); got != "crash=1, passed=5, sdc=2" {
		t.Errorf("comma-joined = %q", got)
	}
}

// Summary.String reuses FormatCounts and keeps its "no trials" empty sentinel.
func TestSummaryStringReusesFormatCounts(t *testing.T) {
	if got := (Summary{}).String(); got != "no trials" {
		t.Errorf("empty Summary = %q, want \"no trials\"", got)
	}
	s := Summary{Counts: map[string]int{"passed": 3, "sdc": 1}, Trials: 4}
	if got := s.String(); got != "passed=3, sdc=1" {
		t.Errorf("Summary.String = %q, want \"passed=3, sdc=1\"", got)
	}
}

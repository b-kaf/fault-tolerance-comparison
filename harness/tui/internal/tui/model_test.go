package tui

import (
	"context"
	"slices"
	"strings"
	"testing"

	tea "github.com/charmbracelet/bubbletea"
)

func update(t *testing.T, m model, msg tea.Msg) model {
	t.Helper()
	next, _ := m.Update(msg)
	return next.(model)
}

func keyType(t tea.KeyType) tea.KeyMsg { return tea.KeyMsg{Type: t} }

func TestNewModelDefaults(t *testing.T) {
	m := newModel("/repo")
	if m.mode != modeE2E {
		t.Errorf("default mode = %v, want e2e", m.mode)
	}
	if got := m.e2eFields[fTechnique].value(); got != "tmr" {
		t.Errorf("default technique = %q, want tmr", got)
	}
	if got := m.e2eFields[fCampaign].value(); got != "mixed" {
		t.Errorf("default campaign = %q, want mixed", got)
	}
	csv := m.e2eFields[fE2ECSV].value()
	if !strings.HasPrefix(csv, "results/e2e-tmr-zig-mixed-") || !strings.HasSuffix(csv, ".csv") {
		t.Errorf("auto CSV name = %q, want results/e2e-tmr-zig-mixed-<ts>.csv", csv)
	}
}

func TestModeToggle(t *testing.T) {
	m := newModel("/repo")
	// focus starts on the mode toggle; right switches to fuzz.
	m = update(t, m, keyType(tea.KeyRight))
	if m.mode != modeFuzz {
		t.Fatalf("after toggle, mode = %v, want fuzz", m.mode)
	}
	if got := m.fuzzFields[fzCampaign].value(); got != "reg-bitflip" {
		t.Errorf("fuzz default campaign = %q, want reg-bitflip", got)
	}
	csv := m.fuzzFields[fzCSV].value()
	if !strings.HasPrefix(csv, "results/fuzz-") {
		t.Errorf("fuzz auto CSV = %q, want results/fuzz-...", csv)
	}
}

func TestFocusNavigationWraps(t *testing.T) {
	m := newModel("/repo")
	if !m.onMode() {
		t.Fatal("focus should start on mode toggle")
	}
	total := m.actionBarIndex() + 1
	for range total {
		m = update(t, m, keyType(tea.KeyTab))
	}
	if !m.onMode() {
		t.Errorf("after %d tabs focus = %d, want wrap to mode (0)", total, m.focus)
	}
	// shift-tab from mode wraps to the action bar.
	m = update(t, m, keyType(tea.KeyShiftTab))
	if !m.onActions() {
		t.Errorf("shift-tab from mode should land on actions, focus = %d", m.focus)
	}
}

func TestCampaignReloadsOnTechniqueChange(t *testing.T) {
	m := newModel("/repo")
	// Move focus to the technique field (focus index 1).
	m = update(t, m, keyType(tea.KeyTab))
	if m.focus != 1 {
		t.Fatalf("focus = %d, want technique field (1)", m.focus)
	}
	// Cycle technique forward to "checkpoint".
	m = update(t, m, keyType(tea.KeyRight))
	if got := m.e2eFields[fTechnique].value(); got != "checkpoint" {
		t.Fatalf("technique = %q, want checkpoint", got)
	}
	campaigns := m.e2eFields[fCampaign].options
	if !slices.Contains(campaigns, "checkpoint-double-fault") {
		t.Errorf("checkpoint campaigns = %v, want checkpoint-double-fault present", campaigns)
	}
	if slices.Contains(campaigns, "single-a") {
		t.Errorf("checkpoint campaigns should not include single-a: %v", campaigns)
	}
}

func TestStartInvalidIterationsShowsError(t *testing.T) {
	m := newModel("/repo")
	m.e2eFields[fIterations].input.SetValue("abc")
	next, cmd := m.startRun()
	m = next.(model)
	if m.state != stateIdle {
		t.Errorf("state = %v, want idle (no run launched)", m.state)
	}
	if m.statusKind != statusError {
		t.Errorf("statusKind = %v, want error", m.statusKind)
	}
	if cmd != nil {
		t.Errorf("expected no command for invalid input")
	}
}

func TestStartMissingELFShowsError(t *testing.T) {
	// A repoRoot with no zig-out: ResolveE2E fails on the ELF stat, surfaced
	// as a status error without launching the engine.
	m := newModel(t.TempDir())
	next, _ := m.startRun()
	m = next.(model)
	if m.state != stateIdle {
		t.Errorf("state = %v, want idle", m.state)
	}
	if m.statusKind != statusError || !strings.Contains(m.status, "ELF not found") {
		t.Errorf("status = %q (kind %v), want ELF-not-found error", m.status, m.statusKind)
	}
}

func TestEngineProgressAndFinished(t *testing.T) {
	m := newModel("/repo")
	m.state = stateRunning
	m.progressTot = 10

	m = update(t, m, engineProgressMsg{cur: 4, total: 10})
	if m.progressCur != 4 {
		t.Errorf("progressCur = %d, want 4", m.progressCur)
	}

	m = update(t, m, engineRowMsg{e2eRow: map[string]any{"technique": "tmr"}})
	if len(m.e2eRows) != 1 {
		t.Errorf("e2eRows = %d, want 1", len(m.e2eRows))
	}

	m = update(t, m, engineFinishedMsg{summary: "passes=10 failures=0", success: true})
	if m.state != stateIdle {
		t.Errorf("state = %v, want idle after finish", m.state)
	}
	if m.statusKind != statusOK {
		t.Errorf("statusKind = %v, want OK", m.statusKind)
	}
}

func TestFinishedCancellationKeepsPartial(t *testing.T) {
	m := newModel("/repo")
	m.state = stateRunning
	m = update(t, m, engineFinishedMsg{err: context.Canceled})
	if m.state != stateIdle {
		t.Errorf("state = %v, want idle", m.state)
	}
	if m.statusKind != statusWarn || !strings.Contains(m.status, "partial") {
		t.Errorf("status = %q (kind %v), want partial-results warning", m.status, m.statusKind)
	}
}

func TestFuzzHistogramAccumulates(t *testing.T) {
	m := newModel("/repo")
	m = update(t, m, keyType(tea.KeyRight)) // switch to fuzz
	m.state = stateRunning
	m = update(t, m, engineProgressMsg{cur: 1, total: 3, resultClass: "passed"})
	m = update(t, m, engineProgressMsg{cur: 2, total: 3, resultClass: "passed"})
	m = update(t, m, engineProgressMsg{cur: 3, total: 3, resultClass: "sdc"})
	if m.histogram["passed"] != 2 || m.histogram["sdc"] != 1 {
		t.Errorf("histogram = %v, want passed=2 sdc=1", m.histogram)
	}
}

func TestBuildFinishedStatus(t *testing.T) {
	m := newModel("/repo")
	m.state = stateBuilding
	ok := update(t, m, buildFinishedMsg{})
	if ok.state != stateIdle || ok.statusKind != statusOK {
		t.Errorf("build success: state=%v kind=%v, want idle/OK", ok.state, ok.statusKind)
	}
}

func TestCSVEditStopsRegeneration(t *testing.T) {
	m := newModel("/repo")
	original := m.e2eFields[fE2ECSV].value()
	// Move focus to the CSV field and type into it.
	for !m.isCSVField() {
		m = update(t, m, keyType(tea.KeyTab))
		if m.onActions() {
			t.Fatal("never reached CSV field")
		}
	}
	m = update(t, m, tea.KeyMsg{Type: tea.KeyRunes, Runes: []rune("x")})
	if !m.csvEdited {
		t.Fatal("typing in CSV field should set csvEdited")
	}
	// Changing a select must no longer overwrite the edited path.
	m.focus = 1 // technique
	m = update(t, m, keyType(tea.KeyRight))
	if m.e2eFields[fE2ECSV].value() == original {
		t.Error("CSV path unexpectedly reverted to auto-name after manual edit")
	}
}

func TestViewRendersPanes(t *testing.T) {
	m := newModel("/repo")
	m.width, m.height = 100, 40
	view := m.View()
	for _, want := range []string{"Harness Runner", "Mode", "Configuration", "Technique", "Actions", "Start", "Results"} {
		if !strings.Contains(view, want) {
			t.Errorf("view missing %q", want)
		}
	}
}

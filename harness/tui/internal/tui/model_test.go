package tui

import (
	"context"
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"slices"
	"strings"
	"testing"

	tea "github.com/charmbracelet/bubbletea"

	"github.com/b-kaf/fault-tolerance-comparison/harness/tui/internal/result"
)

func update(t *testing.T, m model, msg tea.Msg) model {
	t.Helper()
	next, _ := m.Update(msg)
	return next.(model)
}

func keyType(t tea.KeyType) tea.KeyMsg { return tea.KeyMsg{Type: t} }

func keyRune(r rune) tea.KeyMsg { return tea.KeyMsg{Type: tea.KeyRunes, Runes: []rune{r}} }

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

func TestVimKeysNavigate(t *testing.T) {
	m := newModel("/repo")
	// 'l' acts like → on the mode toggle: switch to fuzz.
	m = update(t, m, keyRune('l'))
	if m.mode != modeFuzz {
		t.Fatalf("after 'l', mode = %v, want fuzz", m.mode)
	}
	// 'j' acts like ↓: advance focus off the mode toggle onto the first field.
	m = update(t, m, keyRune('j'))
	if m.focus != 1 {
		t.Fatalf("after 'j', focus = %d, want first field (1)", m.focus)
	}
	// 'k' acts like ↑: back to the mode toggle.
	m = update(t, m, keyRune('k'))
	if !m.onMode() {
		t.Errorf("after 'k', focus = %d, want mode toggle", m.focus)
	}
}

func TestVimKeysAreLiteralInTextField(t *testing.T) {
	m := newModel("/repo")
	// Focus the Iterations text field (last e2e field).
	for m.focus != fIterations+1 {
		m = update(t, m, keyType(tea.KeyTab))
	}
	if f := m.focusedField(); f == nil || f.kind != textKind {
		t.Fatalf("focus %d is not a text field", m.focus)
	}
	before := m.focus
	// 'j' should be typed into the field, not move focus.
	m = update(t, m, keyRune('j'))
	if m.focus != before {
		t.Errorf("focus moved on 'j' in text field: %d, want %d", m.focus, before)
	}
	if got := m.e2eFields[fIterations].value(); !strings.HasSuffix(got, "j") {
		t.Errorf("text field value = %q, want trailing 'j'", got)
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

// A run that completes without an error but reports failures (success=false)
// must not be shown as a green "done" (finding #2): the outcome is flagged as
// a warning so a failing-but-completed e2e campaign is visually distinct.
func TestFinishedWithFailuresWarns(t *testing.T) {
	m := newModel("/repo")
	m.state = stateRunning
	m = update(t, m, engineFinishedMsg{summary: "passes=18 failures=2 (20 iterations)", success: false})
	if m.state != stateIdle {
		t.Errorf("state = %v, want idle after finish", m.state)
	}
	if m.statusKind != statusWarn {
		t.Errorf("statusKind = %v, want warn for a completed run with failures", m.statusKind)
	}
	if !strings.Contains(m.status, "failures") {
		t.Errorf("status = %q, want it to mention failures", m.status)
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

// Export is on demand: with no results, activating it must not open the prompt
// and must warn instead of writing anything.
func TestExportWithNoResultsWarns(t *testing.T) {
	m := newModel("/repo")
	next, _ := m.beginExport()
	m = next.(model)
	if m.exporting {
		t.Error("export prompt should not open when there are no results")
	}
	if m.statusKind != statusWarn {
		t.Errorf("statusKind = %v, want warn", m.statusKind)
	}
}

// Activating Export opens a prompt pre-filled with an auto-named CSV path for
// the active mode; the run itself never writes a CSV anymore.
func TestExportPromptOpensWithAutoName(t *testing.T) {
	m := newModel("/repo")
	m.e2eRows = []result.Row{{"technique": "tmr"}}
	next, _ := m.beginExport()
	m = next.(model)
	if !m.exporting {
		t.Fatal("export prompt should be open after activating Export with results")
	}
	path := m.exportInput.Value()
	if !strings.HasPrefix(path, "results/e2e-tmr-zig-mixed-") || !strings.HasSuffix(path, ".csv") {
		t.Errorf("prompt path = %q, want results/e2e-tmr-zig-mixed-<ts>.csv", path)
	}
}

// Esc cancels the prompt without writing; the rows are untouched.
func TestExportPromptEscCancels(t *testing.T) {
	m := newModel("/repo")
	m.e2eRows = []result.Row{{"technique": "tmr"}}
	next, _ := m.beginExport()
	m = next.(model)
	m = update(t, m, keyType(tea.KeyEsc))
	if m.exporting {
		t.Error("esc should close the export prompt")
	}
	if m.statusKind != statusInfo || !strings.Contains(m.status, "cancel") {
		t.Errorf("status = %q (kind %v), want a cancel info message", m.status, m.statusKind)
	}
}

// Enter on the prompt writes the in-memory rows to the typed path and reports
// the count; the run no longer auto-exports, so this is the only write path.
func TestExportPromptEnterWritesCSV(t *testing.T) {
	m := newModel("/repo")
	m.e2eRows = []result.Row{{"technique": "tmr"}, {"technique": "tmr"}}
	next, _ := m.beginExport()
	m = next.(model)

	path := filepath.Join(t.TempDir(), "out.csv")
	m.exportInput.SetValue(path)
	m = update(t, m, keyType(tea.KeyEnter))

	if m.exporting {
		t.Error("a successful export should close the prompt")
	}
	if m.statusKind != statusOK || !strings.Contains(m.status, "exported 2 rows") {
		t.Errorf("status = %q (kind %v), want an OK 'exported 2 rows' message", m.status, m.statusKind)
	}
	if _, err := os.Stat(path); err != nil {
		t.Errorf("expected CSV at %s: %v", path, err)
	}
}

// An empty path on Enter is rejected and the prompt stays open so the user can
// fix it (no file is written).
func TestExportPromptRejectsEmptyPath(t *testing.T) {
	m := newModel("/repo")
	m.e2eRows = []result.Row{{"technique": "tmr"}}
	next, _ := m.beginExport()
	m = next.(model)
	m.exportInput.SetValue("   ")
	m = update(t, m, keyType(tea.KeyEnter))
	if !m.exporting {
		t.Error("prompt should stay open on an empty path")
	}
	if m.statusKind != statusError {
		t.Errorf("statusKind = %v, want error for empty path", m.statusKind)
	}
}

// isCancel must recognize a (possibly wrapped) context.Canceled and must NOT
// be fooled by an unrelated error whose text merely contains the phrase
// (finding #7).
func TestIsCancelUsesErrorsIs(t *testing.T) {
	if !isCancel(context.Canceled) {
		t.Error("bare context.Canceled should be a cancel")
	}
	wrapped := fmt.Errorf("could not save partial results: disk full (%w)", context.Canceled)
	if !isCancel(wrapped) {
		t.Error("wrapped context.Canceled should be a cancel")
	}
	if isCancel(errors.New("gdb log line mentioning context canceled")) {
		t.Error("an unrelated error that merely mentions the phrase must not be a cancel")
	}
	if isCancel(nil) {
		t.Error("nil is not a cancel")
	}
}

// A Stop whose partial-save failed is wrapped around context.Canceled, so it is
// still classified as a stop (warn), with the save failure surfaced (finding #8).
func TestFinishedWrappedCancelIsStopWithDetail(t *testing.T) {
	m := newModel("/repo")
	m.state = stateRunning
	wrapped := fmt.Errorf("could not save partial results: boom (%w)", context.Canceled)
	m = update(t, m, engineFinishedMsg{err: wrapped})
	if m.statusKind != statusWarn {
		t.Errorf("statusKind = %v, want warn (a stop, not a hard error)", m.statusKind)
	}
	if !strings.Contains(m.status, "could not save partial results") {
		t.Errorf("status = %q, want it to surface the save failure", m.status)
	}
}

// Switching mode must reset the action cursor so it can't be left on an action
// that is disabled in the new state (finding #10).
func TestModeSwitchResetsActionCursor(t *testing.T) {
	m := newModel("/repo")
	m.actionCursor = actStop // disabled while idle
	m.focus = 0
	m = update(t, m, keyType(tea.KeyRight))
	if m.mode != modeFuzz {
		t.Fatalf("mode = %v, want fuzz", m.mode)
	}
	if m.actionCursor != actStart {
		t.Errorf("actionCursor = %v after mode switch, want actStart", m.actionCursor)
	}
}

// envDefaultString returns the raw env value (honoring a literal 0) and the
// default when unset, rather than round-tripping through a u64 parse (finding #9).
func TestEnvDefaultStringRawValue(t *testing.T) {
	if got := envDefaultString("HARNESS_TUI_TEST_UNSET_VAR", "0xC0DEC0DE"); got != "0xC0DEC0DE" {
		t.Errorf("unset = %q, want the default", got)
	}
	t.Setenv("HARNESS_TUI_TEST_SEED", "0")
	if got := envDefaultString("HARNESS_TUI_TEST_SEED", "0xC0DEC0DE"); got != "0" {
		t.Errorf("seed=0 = %q, want \"0\" (a real 0 must not be replaced by the default)", got)
	}
	t.Setenv("HARNESS_TUI_TEST_SEED", "42")
	if got := envDefaultString("HARNESS_TUI_TEST_SEED", "0xC0DEC0DE"); got != "42" {
		t.Errorf("raw = %q, want \"42\" (value must not be reformatted)", got)
	}
}

func TestViewRendersPanes(t *testing.T) {
	m := newModel("/repo")
	m.width, m.height = 100, 40
	view := m.View()
	// The actions bar dropped its "Actions" title to stay thin; the "Start"
	// button still proves it renders.
	for _, want := range []string{"Harness Runner", "Mode", "Configuration", "Technique", "Start", "Results"} {
		if !strings.Contains(view, want) {
			t.Errorf("view missing %q", want)
		}
	}
}

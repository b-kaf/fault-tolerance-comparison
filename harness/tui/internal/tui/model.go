package tui

import (
	"context"
	"errors"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"strings"
	"time"

	"github.com/charmbracelet/bubbles/progress"
	"github.com/charmbracelet/bubbles/spinner"
	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/lipgloss"

	"github.com/b-kaf/fault-tolerance-comparison/harness/tui/internal/config"
	"github.com/b-kaf/fault-tolerance-comparison/harness/tui/internal/e2e"
	"github.com/b-kaf/fault-tolerance-comparison/harness/tui/internal/fuzz"
	"github.com/b-kaf/fault-tolerance-comparison/harness/tui/internal/result"
	"github.com/b-kaf/fault-tolerance-comparison/harness/tui/internal/run"
	"github.com/b-kaf/fault-tolerance-comparison/harness/tui/internal/zigbuild"
)

type appMode int

const (
	modeE2E appMode = iota
	modeFuzz
)

func (m appMode) String() string {
	if m == modeFuzz {
		return "fuzz"
	}
	return "e2e"
}

type runState int

const (
	stateIdle runState = iota
	stateRunning
	stateBuilding
)

// e2e field indices (also the display order).
const (
	fTechnique = iota
	fLanguage
	fCampaign
	fIterations
	fE2ECSV
	e2eFieldCount
)

// fuzz field indices.
const (
	fzTechnique = iota
	fzLanguage
	fzCampaign
	fzTrials
	fzSeed
	fzCSV
	fuzzFieldCount
)

// actions in the action bar, in display order.
type action int

const (
	actStart action = iota
	actStop
	actRebuild
	actExport
	actClear
	actQuit
	actionCount
)

var actionNames = map[action]string{
	actStart:   "Start",
	actStop:    "Stop",
	actRebuild: "Rebuild",
	actExport:  "Export",
	actClear:   "Clear",
	actQuit:    "Quit",
}

type model struct {
	repoRoot string
	mode     appMode

	e2eFields  []field
	fuzzFields []field
	// CSV-path edits are tracked per mode: hand-editing one mode's path must
	// not freeze the other mode's auto-naming, which would leave it empty and
	// silently route that run's CSV to stdout (corrupting the alt-screen TUI).
	e2eCSVEdited  bool
	fuzzCSVEdited bool

	focus        int // 0 = mode toggle, 1..n = fields, n+1 = action bar
	actionCursor action

	state  runState
	cancel context.CancelFunc
	events chan tea.Msg

	progress    progress.Model
	spinner     spinner.Model
	progressCur int
	progressTot int
	histogram   map[string]int // fuzz result-class counts during a run
	// histogramStr caches the rendered histogram so View doesn't re-sort and
	// re-format it on every spinner frame; recomputed only when histogram changes.
	histogramStr string

	// results held for export and shown in the table
	e2eRows  []result.Row
	fuzzRows []map[string]string
	results  resultsTable
	hasTable bool

	status     string
	statusKind statusKind
	buildTail  []string // last lines of build output

	width  int
	height int
	quit   bool
}

type statusKind int

const (
	statusInfo statusKind = iota
	statusOK
	statusWarn
	statusError
)

// Run starts the TUI event loop.
func Run(repoRoot string) error {
	p := tea.NewProgram(newModel(repoRoot), tea.WithAltScreen())
	_, err := p.Run()
	return err
}

func newModel(repoRoot string) model {
	prog := progress.New(progress.WithDefaultGradient())
	prog.Width = 40

	sp := spinner.New()
	sp.Spinner = spinner.Dot

	m := model{
		repoRoot: repoRoot,
		mode:     modeE2E,
		progress: prog,
		spinner:  sp,
		focus:    0,
	}

	defaultTechnique := run.Techniques[0] // tmr
	defaultLanguage := "zig"

	iterDefault := envDefaultInt("HARNESS_E2E_ITERATIONS", 20)
	trialsDefault := envDefaultInt("HARNESS_FUZZ_TRIALS", 20)
	seedDefault := envDefaultString("HARNESS_FUZZ_SEED", "0xC0DEC0DE")

	m.e2eFields = []field{
		fTechnique:  newSelect("Technique", run.Techniques, defaultTechnique),
		fLanguage:   newSelect("Language", run.Languages, defaultLanguage),
		fCampaign:   newSelect("Campaign", e2e.CampaignsForTechnique(defaultTechnique), "mixed"),
		fIterations: newText("Iterations", fmt.Sprintf("%d", iterDefault)),
		fE2ECSV:     newText("CSV path", ""),
	}
	m.fuzzFields = []field{
		fzTechnique: newSelect("Technique", run.Techniques, defaultTechnique),
		fzLanguage:  newSelect("Language", run.Languages, defaultLanguage),
		fzCampaign:  newSelect("Campaign", fuzz.CampaignChoices, "reg-bitflip"),
		fzTrials:    newText("Trials", fmt.Sprintf("%d", trialsDefault)),
		fzSeed:      newText("Seed", seedDefault),
		fzCSV:       newText("CSV path", ""),
	}

	m.regenerateCSV()
	return m
}

func (m model) Init() tea.Cmd {
	return m.spinner.Tick
}

// fields returns the active mode's field slice (a reference into the model).
func (m *model) fields() []field {
	if m.mode == modeFuzz {
		return m.fuzzFields
	}
	return m.e2eFields
}

func (m *model) fieldCount() int { return len(m.fields()) }

// actionBarIndex is the focus value that selects the action bar.
func (m *model) actionBarIndex() int { return m.fieldCount() + 1 }

// resultsIndex is the focus value that selects the results table; only
// reachable when hasTable.
func (m *model) resultsIndex() int { return m.fieldCount() + 2 }

// focusStops is the number of focusable widgets: mode + fields + actions,
// plus the results table once there is one.
func (m *model) focusStops() int {
	stops := m.actionBarIndex() + 1
	if m.hasTable {
		stops++
	}
	return stops
}

func (m *model) onMode() bool    { return m.focus == 0 }
func (m *model) onActions() bool { return m.focus == m.actionBarIndex() }
func (m *model) onField() bool   { return m.focus >= 1 && m.focus <= m.fieldCount() }
func (m *model) onResults() bool { return m.hasTable && m.focus == m.resultsIndex() }

// focusedField returns a pointer to the focused field, or nil.
func (m *model) focusedField() *field {
	if !m.onField() {
		return nil
	}
	return &m.fields()[m.focus-1]
}

func (m model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch msg := msg.(type) {
	case tea.WindowSizeMsg:
		m.width, m.height = msg.Width, msg.Height
		if msg.Width > 8 {
			m.progress.Width = min(msg.Width-8, 60)
		}
		if m.hasTable {
			// Re-flow columns and rows for the new size, keeping the user's
			// page and selected row; the rebuilt table starts blurred, so
			// re-apply focus if the results pane is the active widget.
			m.results.reflow(m.tableWidth(), m.resultsTableHeight())
			if m.onResults() {
				m.results.focus()
			}
		}
		return m, nil

	case spinner.TickMsg:
		var cmd tea.Cmd
		m.spinner, cmd = m.spinner.Update(msg)
		return m, cmd

	case engineProgressMsg:
		m.progressCur = msg.cur
		m.progressTot = msg.total
		if msg.resultClass != "" {
			if m.histogram == nil {
				m.histogram = map[string]int{}
			}
			m.histogram[msg.resultClass]++
			m.histogramStr = sortedHistogram(m.histogram)
		}
		return m, m.listen()

	case engineRowMsg:
		if msg.e2eRow != nil {
			m.e2eRows = append(m.e2eRows, msg.e2eRow)
		}
		if msg.fuzzRow != nil {
			m.fuzzRows = append(m.fuzzRows, msg.fuzzRow)
		}
		return m, m.listen()

	case engineFinishedMsg:
		return m.handleFinished(msg), nil

	case buildOutputMsg:
		m.buildTail = appendTail(m.buildTail, string(msg), 6)
		return m, m.listen()

	case buildFinishedMsg:
		return m.handleBuildFinished(msg), nil

	case tea.KeyMsg:
		return m.handleKey(msg)
	}
	return m, nil
}

func (m model) handleKey(msg tea.KeyMsg) (tea.Model, tea.Cmd) {
	switch msg.String() {
	case "ctrl+c":
		if m.cancel != nil {
			m.cancel()
		}
		m.quit = true
		return m, tea.Quit

	case "esc":
		if m.state != stateIdle && m.cancel != nil {
			m.cancel()
			m.setStatus("stopping…", statusWarn)
		}
		return m, nil

	case "tab":
		m.moveFocus(1)
		return m, m.focusCmd()

	case "shift+tab":
		m.moveFocus(-1)
		return m, m.focusCmd()

	case "up", "down":
		// On the results table up/down scroll rows; elsewhere they move focus.
		if m.onResults() {
			cmd := m.results.update(msg)
			return m, cmd
		}
		if msg.String() == "up" {
			m.moveFocus(-1)
		} else {
			m.moveFocus(1)
		}
		return m, m.focusCmd()
	}

	switch {
	case m.onMode():
		return m.handleModeKey(msg)
	case m.onActions():
		return m.handleActionKey(msg)
	case m.onResults():
		return m.handleResultsKey(msg)
	case m.onField():
		return m.handleFieldKey(msg)
	}
	return m, nil
}

func (m model) handleResultsKey(msg tea.KeyMsg) (tea.Model, tea.Cmd) {
	switch msg.String() {
	case "left":
		m.results.prevPage()
		return m, nil
	case "right":
		m.results.nextPage()
		return m, nil
	case "pgup", "pgdown", "home", "end":
		cmd := m.results.update(msg)
		return m, cmd
	}
	return m, nil
}

func (m model) handleModeKey(msg tea.KeyMsg) (tea.Model, tea.Cmd) {
	switch msg.String() {
	case "left", "right", "enter", " ":
		if m.state != stateIdle {
			m.setStatus("cannot switch mode while busy", statusWarn)
			return m, nil
		}
		if m.mode == modeE2E {
			m.mode = modeFuzz
		} else {
			m.mode = modeE2E
		}
		// Switching mode discards in-memory results (PLAN §4).
		m.clearResults()
		m.focus = 0
		m.actionCursor = actStart // don't leave the cursor on a now-disabled action
		m.regenerateCSV()
		m.setStatus("", statusInfo)
	}
	return m, nil
}

func (m model) handleFieldKey(msg tea.KeyMsg) (tea.Model, tea.Cmd) {
	f := m.focusedField()
	switch f.kind {
	case selectKind:
		switch msg.String() {
		case "left":
			f.cycle(-1)
			m.onSelectChanged()
		case "right":
			f.cycle(1)
			m.onSelectChanged()
		}
		return m, nil
	default: // textKind
		var cmd tea.Cmd
		f.input, cmd = f.input.Update(msg)
		if m.isCSVField() {
			m.setCSVEdited()
		}
		return m, cmd
	}
}

// onSelectChanged reloads campaign choices when technique changes and
// regenerates the auto CSV name.
func (m *model) onSelectChanged() {
	if m.mode == modeE2E {
		technique := m.e2eFields[fTechnique].value()
		m.e2eFields[fCampaign].setOptions(e2e.CampaignsForTechnique(technique))
	}
	m.regenerateCSV()
}

func (m *model) isCSVField() bool {
	if m.mode == modeE2E {
		return m.focus-1 == fE2ECSV
	}
	return m.focus-1 == fzCSV
}

// csvEdited reports whether the active mode's CSV path has been hand-edited.
// Each mode tracks this separately so editing one does not freeze the other's
// auto-naming.
func (m *model) csvEdited() bool {
	if m.mode == modeFuzz {
		return m.fuzzCSVEdited
	}
	return m.e2eCSVEdited
}

// setCSVEdited marks the active mode's CSV path as hand-edited.
func (m *model) setCSVEdited() {
	if m.mode == modeFuzz {
		m.fuzzCSVEdited = true
	} else {
		m.e2eCSVEdited = true
	}
}

func (m model) handleActionKey(msg tea.KeyMsg) (tea.Model, tea.Cmd) {
	switch msg.String() {
	case "left":
		m.actionCursor = action((int(m.actionCursor) - 1 + int(actionCount)) % int(actionCount))
		return m, nil
	case "right":
		m.actionCursor = action((int(m.actionCursor) + 1) % int(actionCount))
		return m, nil
	case "enter", " ":
		return m.activate(m.actionCursor)
	}
	return m, nil
}

func (m model) activate(a action) (tea.Model, tea.Cmd) {
	switch a {
	case actStart:
		return m.startRun()
	case actStop:
		if m.state != stateIdle && m.cancel != nil {
			m.cancel()
			m.setStatus("stopping…", statusWarn)
		}
		return m, nil
	case actRebuild:
		return m.startBuild()
	case actExport:
		return m.exportResults()
	case actClear:
		m.clearResults()
		m.setStatus("cleared results", statusInfo)
		return m, nil
	case actQuit:
		m.quit = true
		return m, tea.Quit
	}
	return m, nil
}

func (m *model) moveFocus(delta int) {
	total := m.focusStops()
	if f := m.focusedField(); f != nil {
		f.blur()
	}
	if m.onResults() {
		m.results.blur()
	}
	m.focus = (m.focus + delta%total + total) % total
	if m.onResults() {
		m.results.focus()
	}
}

// focusCmd focuses the newly-selected text field (if any) so it shows a cursor.
func (m *model) focusCmd() tea.Cmd {
	if f := m.focusedField(); f != nil {
		return f.focus()
	}
	return nil
}

// regenerateCSV recomputes the auto CSV path unless the user has edited it.
func (m *model) regenerateCSV() {
	if m.csvEdited() {
		return
	}
	// Use each layout's own field constants rather than assuming the two
	// layouts share positions 0/1/2 — reordering either must not silently pick
	// the wrong field.
	fields := m.e2eFields
	techIdx, langIdx, campIdx, csvIdx := fTechnique, fLanguage, fCampaign, fE2ECSV
	if m.mode == modeFuzz {
		fields = m.fuzzFields
		techIdx, langIdx, campIdx, csvIdx = fzTechnique, fzLanguage, fzCampaign, fzCSV
	}
	name := autoCSVName(m.mode.String(),
		fields[techIdx].value(),
		fields[langIdx].value(),
		fields[campIdx].value())
	fields[csvIdx].input.SetValue(name)
}

func autoCSVName(mode, technique, language, campaign string) string {
	ts := time.Now().Format("20060102T150405")
	return filepath.Join("results",
		fmt.Sprintf("%s-%s-%s-%s-%s.csv", mode, technique, language, campaign, ts))
}

func (m *model) setStatus(text string, kind statusKind) {
	m.status = text
	m.statusKind = kind
}

// --- async run/build wiring (PLAN §5) ---

type engineProgressMsg struct {
	cur, total  int
	resultClass string
}
type engineRowMsg struct {
	e2eRow  result.Row
	fuzzRow map[string]string
}
type engineFinishedMsg struct {
	summary string
	success bool
	err     error
}
type buildOutputMsg string
type buildFinishedMsg struct{ err error }

// listen returns a command that delivers the next message from the active
// run/build channel, re-issued after each non-terminal message.
func (m model) listen() tea.Cmd {
	ch := m.events
	if ch == nil {
		return nil
	}
	return func() tea.Msg { return <-ch }
}

func (m model) startRun() (tea.Model, tea.Cmd) {
	if m.state != stateIdle {
		return m, nil
	}
	if m.mode == modeE2E {
		return m.startE2E()
	}
	return m.startFuzz()
}

func (m model) startE2E() (tea.Model, tea.Cmd) {
	iterations, ok := parseIntField(m.e2eFields[fIterations].value())
	if !ok {
		m.setStatus("iterations must be a positive integer", statusError)
		return m, nil
	}
	cfg, err := run.ResolveE2E(m.repoRoot,
		m.e2eFields[fTechnique].value(),
		m.e2eFields[fLanguage].value(),
		m.e2eFields[fCampaign].value(),
		iterations,
		m.e2eFields[fE2ECSV].value(),
	)
	if err != nil {
		m.setStatus(err.Error(), statusError)
		return m, nil
	}

	ctx, cancel := context.WithCancel(context.Background())
	ch := make(chan tea.Msg, 256)
	m.cancel = cancel
	m.events = ch
	m.state = stateRunning
	m.clearResults() // drop the previous run's table (and any focus on it)
	m.progressTot = cfg.Iterations
	m.setStatus("running…", statusInfo)

	go func() {
		summary, runErr := e2e.Run(ctx, cfg, e2e.Events{
			OnIteration: func(n, total int, row result.Row) {
				ch <- engineRowMsg{e2eRow: row}
				ch <- engineProgressMsg{cur: n, total: total}
			},
		})
		ch <- engineFinishedMsg{
			summary: fmt.Sprintf("passes=%d failures=%d (%d iterations)",
				summary.Passes, summary.Failures, summary.Iterations),
			success: summary.Success(),
			err:     runErr,
		}
	}()
	return m, tea.Batch(m.listen(), m.spinner.Tick)
}

func (m model) startFuzz() (tea.Model, tea.Cmd) {
	trials, ok := parseIntField(m.fuzzFields[fzTrials].value())
	if !ok {
		m.setStatus("trials must be a positive integer", statusError)
		return m, nil
	}
	cfg, err := run.ResolveFuzz(m.repoRoot,
		m.fuzzFields[fzTechnique].value(),
		m.fuzzFields[fzLanguage].value(),
		m.fuzzFields[fzCampaign].value(),
		trials,
		m.fuzzFields[fzSeed].value(),
		m.fuzzFields[fzCSV].value(),
	)
	if err != nil {
		m.setStatus(err.Error(), statusError)
		return m, nil
	}

	ctx, cancel := context.WithCancel(context.Background())
	ch := make(chan tea.Msg, 256)
	m.cancel = cancel
	m.events = ch
	m.state = stateRunning
	m.clearResults() // drop the previous run's table (and any focus on it)
	m.histogram = map[string]int{}
	m.progressTot = cfg.Trials
	m.setStatus("running…", statusInfo)

	go func() {
		summary, runErr := fuzz.Run(ctx, cfg, io.Discard, fuzz.Events{
			OnTrial: func(trialID, total int, row map[string]string) {
				ch <- engineRowMsg{fuzzRow: row}
				ch <- engineProgressMsg{cur: trialID + 1, total: total, resultClass: row["result_class"]}
			},
		})
		ch <- engineFinishedMsg{summary: summary.String(), success: runErr == nil, err: runErr}
	}()
	return m, tea.Batch(m.listen(), m.spinner.Tick)
}

func (m model) handleFinished(msg engineFinishedMsg) model {
	m.state = stateIdle
	m.cancel = nil
	m.events = nil
	switch {
	case isCancel(msg.err):
		// A deliberate Stop. A bare context.Canceled means the partial results
		// were saved; a wrapped one carries a detail to surface (e.g. the save
		// failed) — still a stop, not a hard error.
		if msg.err == context.Canceled {
			m.setStatus("stopped — partial results kept", statusWarn)
		} else {
			m.setStatus("stopped — "+msg.err.Error(), statusWarn)
		}
	case msg.err != nil:
		m.setStatus("error: "+msg.err.Error(), statusError)
	case msg.success:
		m.setStatus("done — "+msg.summary, statusOK)
	default:
		// Completed without a run error, but the outcome itself is not a
		// clean pass (e.g. an e2e campaign whose final failure counter is
		// non-zero). Mirror the headless non-zero exit by flagging it.
		m.setStatus("completed with failures — "+msg.summary, statusWarn)
	}
	m.buildResultsTable()
	return m
}

// tableWidth is the width used to lay out the results table, with a fallback
// for before the first WindowSizeMsg has arrived.
func (m *model) tableWidth() int {
	if m.width <= 0 {
		return 80
	}
	return m.width
}

// resultsTableHeight is how many rows the results table should show. The table
// is front and centre, so it fills all the vertical space the surrounding
// widgets leave: the terminal height minus the top panes (Mode + Configuration,
// side by side), the actions bar, and the fixed chrome (title, results border +
// header, help line). Both variable panes are measured directly so the fit
// holds across modes and status states; floored at minTableHeight so it never
// collapses. Before the first WindowSizeMsg (m.height == 0) it uses the default.
func (m *model) resultsTableHeight() int {
	if m.height <= 0 {
		return tableHeight
	}
	chrome := lipgloss.Height(m.topPanes()) + lipgloss.Height(m.actionsBar()) + resultsFixedChrome
	return max(m.height-chrome, minTableHeight)
}

// buildResultsTable rebuilds the results table from the in-memory rows for the
// active mode, resetting the column page and selected row. Called on run finish
// (including cancellation, so partial rows show). Window resize uses
// results.reflow instead, to preserve the user's page and row.
func (m *model) buildResultsTable() {
	width := m.tableWidth()
	height := m.resultsTableHeight()
	if m.mode == modeFuzz {
		if len(m.fuzzRows) == 0 {
			m.hasTable = false
			m.dropTableFocus()
			return
		}
		m.results = fuzzResults(m.fuzzRows, width, height)
	} else {
		if len(m.e2eRows) == 0 {
			m.hasTable = false
			m.dropTableFocus()
			return
		}
		m.results = e2eResults(m.e2eRows, width, height)
	}
	m.hasTable = true
	if m.onResults() {
		m.results.focus()
	}
}

// clearResults drops the in-memory results and the table, and pulls focus back
// if it was on the (now-gone) results pane.
func (m *model) clearResults() {
	m.e2eRows = nil
	m.fuzzRows = nil
	m.histogram = nil
	m.histogramStr = ""
	m.progressCur, m.progressTot = 0, 0
	m.hasTable = false
	m.dropTableFocus()
}

// dropTableFocus pulls focus back to the action bar when the results pane has
// just gone away; otherwise focus would point past the last focus stop, leaving
// no widget active and the key handler inert. Called everywhere hasTable is set
// false so the focus invariant holds.
func (m *model) dropTableFocus() {
	if m.focus >= m.focusStops() {
		m.focus = m.actionBarIndex()
	}
}

func (m model) startBuild() (tea.Model, tea.Cmd) {
	if m.state != stateIdle {
		return m, nil
	}
	target := zigbuild.TargetForMode(m.mode.String())

	ctx, cancel := context.WithCancel(context.Background())
	ch := make(chan tea.Msg, 512)
	m.cancel = cancel
	m.events = ch
	m.state = stateBuilding
	m.buildTail = nil
	m.setStatus(fmt.Sprintf("building (zig build %s)…", target), statusInfo)

	go func() {
		err := zigbuild.Run(ctx, m.repoRoot, target, func(line string) {
			ch <- buildOutputMsg(line)
		})
		ch <- buildFinishedMsg{err: err}
	}()
	return m, tea.Batch(m.listen(), m.spinner.Tick)
}

func (m model) handleBuildFinished(msg buildFinishedMsg) model {
	m.state = stateIdle
	m.cancel = nil
	m.events = nil
	if msg.err != nil {
		if isCancel(msg.err) {
			m.setStatus("build cancelled", statusWarn)
		} else {
			m.setStatus("build failed: "+msg.err.Error(), statusError)
		}
	} else {
		m.setStatus("build succeeded", statusOK)
	}
	return m
}

// exportResults writes the in-memory rows back to the active mode's configured
// CSV path.
func (m model) exportResults() (tea.Model, tea.Cmd) {
	var count int
	var path string
	var write func() error
	if m.mode == modeE2E {
		count, path = len(m.e2eRows), m.e2eFields[fE2ECSV].value()
		write = func() error { return result.WriteE2ECSV(path, m.e2eRows) }
	} else {
		count, path = len(m.fuzzRows), m.fuzzFields[fzCSV].value()
		write = func() error { return writeFuzzRows(path, m.fuzzRows) }
	}

	if count == 0 {
		m.setStatus("no results to export", statusWarn)
		return m, nil
	}
	if err := write(); err != nil {
		m.setStatus("export failed: "+err.Error(), statusError)
		return m, nil
	}
	m.setStatus(fmt.Sprintf("exported %d rows to %s", count, path), statusOK)
	return m, nil
}

func writeFuzzRows(path string, rows []map[string]string) error {
	writer, err := result.OpenFuzzCSV(path)
	if err != nil {
		return err
	}
	for _, row := range rows {
		if err := writer.WriteRow(row); err != nil {
			writer.Close()
			return err
		}
	}
	return writer.Close()
}

// --- helpers ---

func parseIntField(s string) (int, bool) {
	v, err := config.ParsePositiveInt(strings.TrimSpace(s))
	if err != nil {
		return 0, false
	}
	return v, true
}

func envDefaultInt(name string, def int64) int64 {
	v, err := config.EnvInt(name, def)
	if err != nil {
		return def
	}
	return v
}

func envDefaultString(name, def string) string {
	if v := os.Getenv(name); v != "" {
		return v
	}
	return def
}

func isCancel(err error) bool {
	return errors.Is(err, context.Canceled)
}

func appendTail(lines []string, line string, max int) []string {
	lines = append(lines, line)
	if len(lines) > max {
		lines = lines[len(lines)-max:]
	}
	return lines
}

// sortedHistogram renders the live result-class counts during a fuzz run,
// reusing the engine's formatter so the in-progress and final summaries can't
// drift.
func sortedHistogram(counts map[string]int) string {
	return fuzz.FormatCounts(counts, " ")
}

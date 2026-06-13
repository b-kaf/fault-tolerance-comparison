package tui

import (
	"strings"
	"testing"

	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/lipgloss"

	"github.com/b-kaf/fault-tolerance-comparison/harness/tui/internal/result"
)

func sampleE2ERows() []result.Row {
	return []result.Row{
		{"technique": "tmr", "implementation": "zig", "campaign": "mixed", "iteration": uint32(1),
			"stage": uint32(3), "fault_target": uint32(0), "fault_value": uint32(0),
			"expected": uint32(0x12345678), "status": uint32(0), "value": uint32(0x12345678),
			"passes": uint32(1), "failures": uint32(0)},
		{"technique": "tmr", "implementation": "zig", "campaign": "mixed", "iteration": uint32(2),
			"stage": uint32(3), "fault_target": uint32(1), "fault_value": uint32(0xFFFFFFFF),
			"expected": uint32(0x9abcdef0), "status": uint32(0), "value": uint32(0x9abcdef0),
			"passes": uint32(2), "failures": uint32(0)},
	}
}

func sampleFuzzRows() []map[string]string {
	return []map[string]string{
		result.FormatFuzzResultRow("tmr", "zig", 0, 0x1, "reg-bitflip", 0xC0DEC0DE, "passed",
			map[string]string{"harness_output": "0x7", "harness_expected": "0x7"}, "completed", false, 100),
		result.FormatFuzzResultRow("tmr", "zig", 1, 0x2, "reg-bitflip", 0xC0DEC0DE, "sdc",
			map[string]string{"harness_output": "0x8", "harness_expected": "0x7"}, "completed", false, 110),
	}
}

func TestPaginateColumnsFitsWidth(t *testing.T) {
	columns := result.FuzzCuratedColumns
	records := [][]string{result.FuzzRecord(sampleFuzzRows()[0], columns)}

	pages := paginateColumns(columns, records, 80)
	if len(pages) < 2 {
		t.Fatalf("31 columns at width 80 should span >1 page, got %d", len(pages))
	}
	// Every column appears exactly once across pages, in order.
	var flat []int
	for _, page := range pages {
		if len(page) == 0 {
			t.Fatal("empty page")
		}
		flat = append(flat, page...)
	}
	if len(flat) != len(columns) {
		t.Errorf("paginated %d columns, want %d", len(flat), len(columns))
	}
	for i, col := range flat {
		if col != i {
			t.Errorf("column order broken at %d: got index %d", i, col)
		}
	}
}

func TestE2ETableMatchesCSVColumns(t *testing.T) {
	rows := sampleE2ERows()
	rt := e2eResults(rows, 200, tableHeight)
	wantCols, wantRecords := result.E2ETable(rows)
	if len(rt.columns) != len(wantCols) {
		t.Fatalf("columns = %v, want %v", rt.columns, wantCols)
	}
	for i := range wantCols {
		if rt.columns[i] != wantCols[i] {
			t.Errorf("column %d = %q, want %q", i, rt.columns[i], wantCols[i])
		}
	}
	if len(rt.records) != len(wantRecords) {
		t.Errorf("records = %d, want %d", len(rt.records), len(wantRecords))
	}
}

func TestFuzzTableCuratedFirst(t *testing.T) {
	rt := fuzzResults(sampleFuzzRows(), 200, tableHeight)
	if rt.columns[0] != "trial_id" || rt.columns[1] != "result_class" {
		t.Errorf("curated columns not first: %v…", rt.columns[:2])
	}
}

func TestResultsAppearAndPageAfterFinish(t *testing.T) {
	m := newModel("/repo")
	m.width, m.height = 80, 40
	m.state = stateRunning
	for _, row := range sampleFuzzRows() {
		// drive through the fuzz row message
		m = update(t, m, engineRowMsg{fuzzRow: row})
	}
	// Switch model to fuzz so buildResultsTable reads fuzzRows.
	m.mode = modeFuzz
	m = update(t, m, engineFinishedMsg{summary: "passed=1, sdc=1", success: true})

	if !m.hasTable {
		t.Fatal("expected a results table after finish")
	}
	if m.resultsIndex() <= m.actionBarIndex() {
		t.Fatal("results focus stop should follow the action bar")
	}

	// Tab around to the results pane.
	guard := 0
	for !m.onResults() {
		m = update(t, m, keyType(tea.KeyTab))
		if guard++; guard > 20 {
			t.Fatal("never reached results focus")
		}
	}

	// Right pages the columns when there are multiple pages.
	if len(m.results.pages) > 1 {
		before := m.results.page
		m = update(t, m, keyType(tea.KeyRight))
		if m.results.page == before {
			t.Errorf("right did not change page (was %d)", before)
		}
	}

	view := m.View()
	if !strings.Contains(view, "rows") {
		t.Error("results pane should show a row count")
	}
}

// A terminal resize re-paginates columns for the new width but must keep the
// user's current column page and selected row (finding #3), rather than
// snapping back to page 0 / row 0.
func TestResizePreservesPageAndCursor(t *testing.T) {
	m := newModel("/repo")
	m.width, m.height = 80, 40
	m.mode = modeFuzz
	m.fuzzRows = sampleFuzzRows()
	m.buildResultsTable()
	if !m.hasTable {
		t.Fatal("setup: expected a table")
	}
	if len(m.results.pages) < 2 {
		t.Fatalf("setup: expected multiple column pages, got %d", len(m.results.pages))
	}

	// Page off the first column page and select a non-first row.
	m.results.nextPage()
	m.results.table.SetCursor(1)
	wantPage := m.results.page
	wantCursor := m.results.table.Cursor()
	if wantPage == 0 {
		t.Fatal("setup: expected to be off the first column page")
	}

	// Resizing (here to a narrower width, which yields at least as many pages)
	// must keep the user's place.
	m = update(t, m, tea.WindowSizeMsg{Width: 60, Height: 40})
	if m.results.page != wantPage {
		t.Errorf("after resize page = %d, want %d (resize reset the column page)", m.results.page, wantPage)
	}
	if got := m.results.table.Cursor(); got != wantCursor {
		t.Errorf("after resize cursor = %d, want %d (resize reset the selected row)", got, wantCursor)
	}
}

// The results table must shrink to fit a short terminal rather than always
// rendering tableHeight rows and overflowing the screen (finding #4); on a
// tall terminal it stays at the full default height.
func TestTableHeightFitsTerminal(t *testing.T) {
	tall := newModel("/repo")
	tall.width, tall.height = 100, 60
	if got := tall.resultsTableHeight(); got != tableHeight {
		t.Errorf("tall terminal table height = %d, want %d", got, tableHeight)
	}

	short := newModel("/repo")
	short.width, short.height = 100, 30
	got := short.resultsTableHeight()
	if got >= tableHeight {
		t.Errorf("short terminal table height = %d, want it shrunk below %d", got, tableHeight)
	}
	if got < minTableHeight {
		t.Errorf("table height = %d, want floored at >= %d", got, minTableHeight)
	}

	// The rendered view must fit within the terminal height on a short screen.
	short.mode = modeFuzz
	short.fuzzRows = sampleFuzzRows()
	short.buildResultsTable()
	if h := lipgloss.Height(short.View()); h > short.height {
		t.Errorf("view height %d exceeds terminal height %d on a short terminal", h, short.height)
	}

	// A very short terminal floors the table rather than going to zero/negative.
	tiny := newModel("/repo")
	tiny.width, tiny.height = 100, 5
	if got := tiny.resultsTableHeight(); got != minTableHeight {
		t.Errorf("tiny terminal table height = %d, want floor %d", got, minTableHeight)
	}
}

// When the results table goes away while focus is on it, focus must be pulled
// back to a reachable widget rather than left stranded past the last focus stop
// (finding #5). This covers both the clearResults path (Clear / start-of-run)
// and the buildResultsTable path (a rebuild that finds no rows).
func TestClearResultsPullsFocusFromResultsPane(t *testing.T) {
	m := newModel("/repo")
	m.width, m.height = 80, 40
	m.e2eRows = sampleE2ERows()
	m.buildResultsTable()
	m.focus = m.resultsIndex()
	if !m.onResults() {
		t.Fatal("setup: expected focus on results")
	}

	m.clearResults()
	if m.hasTable {
		t.Fatal("clearResults should drop the table")
	}
	if m.onResults() || m.focus >= m.focusStops() {
		t.Errorf("focus %d not pulled back after clear (stops=%d)", m.focus, m.focusStops())
	}
}

func TestBuildResultsTableStrandsNoFocus(t *testing.T) {
	m := newModel("/repo")
	m.width, m.height = 80, 40
	m.mode = modeFuzz
	m.fuzzRows = sampleFuzzRows()
	m.buildResultsTable()
	m.focus = m.resultsIndex()
	if !m.onResults() {
		t.Fatal("setup: expected focus on results")
	}

	// Rebuild with the rows gone (e.g. a finish/resize that finds nothing):
	// the table disappears and focus must not be left out of range.
	m.fuzzRows = nil
	m.buildResultsTable()
	if m.hasTable {
		t.Fatal("expected no table after rows cleared")
	}
	if m.onResults() || m.focus >= m.focusStops() {
		t.Errorf("focus %d stranded out of range after table removed (stops=%d)", m.focus, m.focusStops())
	}
}

func TestModeSwitchClearsTable(t *testing.T) {
	m := newModel("/repo")
	m.width = 80
	m.e2eRows = sampleE2ERows()
	m.buildResultsTable()
	if !m.hasTable {
		t.Fatal("setup: expected table")
	}
	// Focus the mode toggle and switch.
	m.focus = 0
	m = update(t, m, keyType(tea.KeyRight))
	if m.hasTable {
		t.Error("mode switch should clear the results table")
	}
	if m.focus >= m.focusStops() {
		t.Errorf("focus %d out of range after clearing table (stops=%d)", m.focus, m.focusStops())
	}
}

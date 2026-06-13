package tui

import (
	"strings"
	"testing"

	tea "github.com/charmbracelet/bubbletea"

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

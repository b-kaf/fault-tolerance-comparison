package tui

import (
	"github.com/charmbracelet/bubbles/table"
	tea "github.com/charmbracelet/bubbletea"

	"github.com/b-kaf/fault-tolerance-comparison/harness/tui/internal/result"
)

// resultsTable wraps bubbles/table with column paging, since the widget has no
// horizontal scroll and both the 31-column fuzz schema and the wide e2e
// techniques exceed a terminal's width (PLAN §4).
type resultsTable struct {
	columns   []string   // full ordered column set
	records   [][]string // full data, all columns
	colWidths []int      // rendered width per column, computed once at build
	pages     [][]int    // column indices per page
	page      int
	table     table.Model
	width     int
	height    int
}

const (
	maxColWidth = 18
	// tableHeight is the default/maximum number of rows the results table
	// shows; resultsTableHeight shrinks it to fit a short terminal.
	tableHeight = 10
	// minTableHeight is the floor so a short terminal still shows a few rows
	// rather than collapsing the table to nothing.
	minTableHeight = 3
	// resultsChrome is the vertical space the rest of the UI occupies around
	// the table (title, the mode/config/actions panes and their borders,
	// inter-pane spacing, the results pane border+header, and the help line).
	// Measured at ~24-25 lines; we reserve a little more to absorb the status
	// area growing during a run.
	resultsChrome = 27
	colCellMargin = 2 // bubbles/table cell padding
)

// e2eResults builds a results table from collected e2e rows.
func e2eResults(rows []result.Row, width, height int) resultsTable {
	columns, records := result.E2ETable(rows)
	return newResultsTable(columns, records, width, height)
}

// fuzzResults builds a results table from collected fuzz rows, curated columns
// first.
func fuzzResults(rows []map[string]string, width, height int) resultsTable {
	columns := result.FuzzCuratedColumns
	records := make([][]string, len(rows))
	for i, row := range rows {
		records[i] = result.FuzzRecord(row, columns)
	}
	return newResultsTable(columns, records, width, height)
}

func newResultsTable(columns []string, records [][]string, width, height int) resultsTable {
	rt := resultsTable{
		columns:   columns,
		records:   records,
		colWidths: computeColWidths(columns, records),
		width:     width,
		height:    height,
	}
	rt.pages = paginateColumns(rt.colWidths, width)
	rt.rebuild()
	return rt
}

// computeColWidths returns the rendered width of each column — the widest of
// header/cells, capped at maxColWidth. The data never changes after build, so
// this is computed once and reused by pagination and rebuild rather than
// re-scanning every cell on each resize.
func computeColWidths(columns []string, records [][]string) []int {
	widths := make([]int, len(columns))
	for col := range columns {
		w := len(columns[col])
		for _, record := range records {
			if col < len(record) && len(record[col]) > w {
				w = len(record[col])
			}
		}
		widths[col] = min(w, maxColWidth)
	}
	return widths
}

// paginateColumns groups columns into pages that fit the available width, using
// the precomputed per-column widths. Each page holds at least one column so a
// very narrow terminal still works.
func paginateColumns(colWidths []int, width int) [][]int {
	avail := max(width-4, 10) // pane border + padding
	var pages [][]int
	var current []int
	used := 0
	for col, cw := range colWidths {
		w := cw + colCellMargin
		if len(current) > 0 && used+w > avail {
			pages = append(pages, current)
			current = nil
			used = 0
		}
		current = append(current, col)
		used += w
	}
	if len(current) > 0 {
		pages = append(pages, current)
	}
	if len(pages) == 0 {
		pages = [][]int{{}}
	}
	return pages
}

// rebuild sets the table's columns and rows for the current page.
func (rt *resultsTable) rebuild() {
	if len(rt.pages) == 0 {
		return
	}
	if rt.page >= len(rt.pages) {
		rt.page = len(rt.pages) - 1
	}
	indices := rt.pages[rt.page]

	cols := make([]table.Column, len(indices))
	for i, col := range indices {
		cols[i] = table.Column{Title: rt.columns[col], Width: rt.colWidths[col]}
	}
	rows := make([]table.Row, len(rt.records))
	for r, record := range rt.records {
		cells := make(table.Row, len(indices))
		for i, col := range indices {
			if col < len(record) {
				cells[i] = record[col]
			}
		}
		rows[r] = cells
	}

	h := rt.height
	if h <= 0 {
		h = tableHeight
	}
	rt.table = table.New(
		table.WithColumns(cols),
		table.WithRows(rows),
		table.WithHeight(h),
	)
}

// reflow re-paginates the columns for a new available width and height while
// preserving the current page (clamped to the new page count by rebuild) and
// the selected row. The data is unchanged on a resize; only the size-dependent
// column grouping and row count are recomputed. Focus is left to the caller —
// rebuild starts the new table blurred.
func (rt *resultsTable) reflow(width, height int) {
	cursor := rt.table.Cursor()
	rt.width = width
	rt.height = height
	rt.pages = paginateColumns(rt.colWidths, width)
	rt.rebuild()
	rt.table.SetCursor(cursor)
}

func (rt *resultsTable) focus() { rt.table.Focus() }
func (rt *resultsTable) blur()  { rt.table.Blur() }

func (rt *resultsTable) nextPage() {
	if len(rt.pages) > 1 {
		cursor := rt.table.Cursor()
		rt.page = (rt.page + 1) % len(rt.pages)
		rt.rebuild()
		rt.table.SetCursor(cursor) // keep the same row selected across pages
		rt.table.Focus()
	}
}

func (rt *resultsTable) prevPage() {
	if len(rt.pages) > 1 {
		cursor := rt.table.Cursor()
		rt.page = (rt.page - 1 + len(rt.pages)) % len(rt.pages)
		rt.rebuild()
		rt.table.SetCursor(cursor)
		rt.table.Focus()
	}
}

func (rt *resultsTable) update(msg tea.Msg) tea.Cmd {
	var cmd tea.Cmd
	rt.table, cmd = rt.table.Update(msg)
	return cmd
}

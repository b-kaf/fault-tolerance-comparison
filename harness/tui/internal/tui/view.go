package tui

import (
	"fmt"
	"strings"

	"github.com/charmbracelet/lipgloss"
)

func (m model) View() string {
	if m.quit {
		return ""
	}
	var b strings.Builder
	b.WriteString(titleStyle.Render("Harness Runner"))
	b.WriteString("\n\n")
	b.WriteString(m.topPanes())
	b.WriteString("\n")
	b.WriteString(m.resultsPane())
	b.WriteString("\n")
	b.WriteString(m.actionsBar())
	b.WriteString("\n")
	b.WriteString(mutedStyle.Render(helpForFocus(m.focusHint())))
	return b.String()
}

// topPanes places the Mode and Configuration panes side by side. Mode keeps its
// natural width; Configuration gets the rest of the terminal (capped so a long
// CSV path can't overflow), and the shorter box is padded to the taller's
// height so the two align at the bottom.
func (m model) topPanes() string {
	mode := m.modePane(0)
	// Width left for the config pane after the mode pane and the 2-col gap. A
	// zero cap (before the first window-size message) means "render natural".
	configMax := 0
	if m.width > 0 {
		configMax = max(m.width-lipgloss.Width(mode)-2, minConfigWidth)
	}
	config := m.configPane(0, configMax)
	// Shared content height: the taller box's total height minus its border (2).
	h := max(lipgloss.Height(mode), lipgloss.Height(config)) - 2
	return lipgloss.JoinHorizontal(lipgloss.Top, m.modePane(h), "  ", m.configPane(h, configMax))
}

func (m model) focusHint() focusHint {
	switch {
	case m.onResults():
		return hintResults
	case m.onActions():
		return hintActions
	default:
		return hintDefault
	}
}

// modePane renders the Mode toggle. A height > 0 pads the box to that content
// height so it can be aligned beside the taller Configuration pane.
func (m model) modePane(height int) string {
	e2eStyle, fuzzStyle := buttonStyle, buttonFocusedStyle
	if m.mode == modeE2E {
		e2eStyle, fuzzStyle = buttonFocusedStyle, buttonStyle
	}
	content := e2eStyle.Render("E2E Injector") + "  " + fuzzStyle.Render("Fuzz Runner")
	if m.onMode() {
		content += "\n\n" + mutedStyle.Render("←→ switch mode")
	}
	style := paneStyle
	if m.onMode() {
		style = paneFocusedStyle
	}
	if height > 0 {
		style = style.Height(height)
	}
	return style.Render(paneTitle("Mode") + "\n" + content)
}

// configPane renders the Configuration fields. A height > 0 pads the box (see
// modePane). A maxWidth > 0 caps the box to that total width, truncating a long
// CSV path rather than letting it push the side-by-side layout off-screen;
// shorter content keeps its natural width.
func (m model) configPane(height, maxWidth int) string {
	fields := m.fields()
	var lines []string
	for i := range fields {
		focused := m.onField() && m.focus-1 == i
		lines = append(lines, renderField(fields[i], focused))
	}
	content := paneTitle("Configuration") + "\n" + strings.Join(lines, "\n")
	if maxWidth > 0 {
		// Truncate the content to the inner width (the box adds border 2 +
		// padding 2). MaxWidth truncates per line without wrapping, so the box
		// height is unchanged.
		content = lipgloss.NewStyle().MaxWidth(maxWidth - 4).Render(content)
	}
	style := paneStyle
	if m.onField() {
		style = paneFocusedStyle
	}
	if height > 0 {
		style = style.Height(height)
	}
	return style.Render(content)
}

// actionsBar is the thin action strip at the bottom: a single row of buttons
// over the status line, with no pane title so it stays out of the table's way.
func (m model) actionsBar() string {
	var buttons []string
	for i := range int(actionCount) {
		a := action(i)
		style := buttonStyle
		switch {
		case !m.actionEnabled(a):
			style = buttonDisabledStyle
		case m.onActions() && a == m.actionCursor:
			style = buttonFocusedStyle
		}
		buttons = append(buttons, style.Render(actionNames[a]))
	}
	bar := strings.Join(buttons, " ")

	style := paneStyle
	if m.onActions() {
		style = paneFocusedStyle
	}
	return style.Render(bar + "\n" + m.statusLine())
}

func (m model) actionEnabled(a action) bool {
	switch a {
	case actStart, actRebuild:
		return m.state == stateIdle
	case actStop:
		return m.state != stateIdle
	case actExport, actClear:
		return m.resultCount() > 0
	case actQuit:
		return true
	}
	return false
}

func (m model) resultCount() int {
	if m.mode == modeFuzz {
		return len(m.fuzzRows)
	}
	return len(m.e2eRows)
}

func (m model) statusLine() string {
	var parts []string

	if m.state != stateIdle {
		spin := m.spinner.View()
		switch m.state {
		case stateRunning:
			unit := "iteration"
			if m.mode == modeFuzz {
				unit = "trial"
			}
			bar := m.progress.ViewAs(m.fraction())
			parts = append(parts, fmt.Sprintf("%s %s %d/%d %s",
				spin, unit, m.progressCur, m.progressTot, bar))
		case stateBuilding:
			parts = append(parts, spin+" building")
		}
	}

	if status := m.renderStatus(); status != "" {
		parts = append(parts, status)
	}

	if m.mode == modeFuzz && m.histogramStr != "" {
		parts = append(parts, mutedStyle.Render(m.histogramStr))
	}

	if m.state == stateBuilding && len(m.buildTail) > 0 {
		parts = append(parts, mutedStyle.Render(strings.Join(m.buildTail, "\n")))
	}

	if len(parts) == 0 {
		return mutedStyle.Render("idle")
	}
	return strings.Join(parts, "\n")
}

func (m model) renderStatus() string {
	if m.status == "" {
		return ""
	}
	switch m.statusKind {
	case statusOK:
		return okStyle.Render(m.status)
	case statusWarn:
		return warnStyle.Render(m.status)
	case statusError:
		return errStyle.Render(m.status)
	default:
		return valueStyle.Render(m.status)
	}
}

func (m model) fraction() float64 {
	if m.progressTot <= 0 {
		return 0
	}
	return float64(m.progressCur) / float64(m.progressTot)
}

func (m model) resultsPane() string {
	style := paneStyle
	if m.onResults() {
		style = paneFocusedStyle
	}

	if !m.hasTable {
		return style.Render(paneTitle("Results") + "\n" +
			mutedStyle.Render("no results yet — run a campaign"))
	}

	header := paneTitle("Results")
	header += "  " + mutedStyle.Render(fmt.Sprintf("%d rows", m.resultCount()))
	if pages := len(m.results.pages); pages > 1 {
		cols := m.results.pages[m.results.page]
		first, last := m.results.columns[cols[0]], m.results.columns[cols[len(cols)-1]]
		header += "  " + mutedStyle.Render(fmt.Sprintf("cols %s…%s · page %d/%d",
			first, last, m.results.page+1, pages))
		if m.onResults() {
			header += " " + mutedStyle.Render("(←→)")
		}
	}
	return style.Render(header + "\n" + m.results.table.View())
}

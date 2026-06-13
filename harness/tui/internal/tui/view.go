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
	b.WriteString(m.modePane())
	b.WriteString("\n")
	b.WriteString(m.configPane())
	b.WriteString("\n")
	b.WriteString(m.actionsPane())
	b.WriteString("\n")
	b.WriteString(m.resultsPane())
	b.WriteString("\n\n")
	b.WriteString(mutedStyle.Render(helpForFocus(m.onActions())))
	return b.String()
}

func (m model) modePane() string {
	e2eLabel := "  E2E Injector  "
	fuzzLabel := "  Fuzz Runner  "
	if m.mode == modeE2E {
		e2eLabel = buttonFocusedStyle.Render("E2E Injector")
		fuzzLabel = buttonStyle.Render("Fuzz Runner")
	} else {
		e2eLabel = buttonStyle.Render("E2E Injector")
		fuzzLabel = buttonFocusedStyle.Render("Fuzz Runner")
	}
	content := e2eLabel + "  " + fuzzLabel
	if m.onMode() {
		content += "   " + mutedStyle.Render("←→ switch")
	}
	style := paneStyle
	if m.onMode() {
		style = paneFocusedStyle
	}
	return style.Render(paneTitle("Mode") + "\n" + content)
}

func (m model) configPane() string {
	fields := m.fields()
	var lines []string
	for i := range fields {
		focused := m.onField() && m.focus-1 == i
		lines = append(lines, renderField(fields[i], focused))
	}
	style := paneStyle
	if m.onField() {
		style = paneFocusedStyle
	}
	return style.Render(paneTitle("Configuration") + "\n" + strings.Join(lines, "\n"))
}

func (m model) actionsPane() string {
	var buttons []string
	for i := range int(actionCount) {
		a := action(i)
		label := actionNames[a]
		style := buttonStyle
		switch {
		case !m.actionEnabled(a):
			style = buttonDisabledStyle
		case m.onActions() && a == m.actionCursor:
			style = buttonFocusedStyle
		}
		buttons = append(buttons, style.Render(label))
	}
	bar := strings.Join(buttons, " ")

	style := paneStyle
	if m.onActions() {
		style = paneFocusedStyle
	}
	return style.Render(paneTitle("Actions") + "\n" + bar + "\n" + m.statusLine())
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

	if m.mode == modeFuzz {
		if hist := sortedHistogram(m.histogram); hist != "" {
			parts = append(parts, mutedStyle.Render(hist))
		}
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
	count := m.resultCount()
	var body string
	if count == 0 {
		body = mutedStyle.Render("no results yet — run a campaign")
	} else {
		// The bubbles/table view lands in phase 6; for now report the count.
		body = valueStyle.Render(fmt.Sprintf("%d rows collected (table view: phase 6)", count))
	}
	return paneStyle.Render(paneTitle("Results") + "\n" + body)
}

// ensure lipgloss is referenced even if helpers above are trimmed during edits
var _ = lipgloss.Width

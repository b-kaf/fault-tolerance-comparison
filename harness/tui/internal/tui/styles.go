package tui

import (
	"github.com/charmbracelet/bubbles/table"
	"github.com/charmbracelet/lipgloss"
)

// Palette and reusable styles for the TUI panes — gruvbox dark.
var (
	colorBg       = lipgloss.Color("#282828") // gruvbox bg0
	colorAccent   = lipgloss.Color("#fabd2f") // gruvbox bright yellow
	colorMuted    = lipgloss.Color("#928374") // gruvbox gray
	colorOK       = lipgloss.Color("#b8bb26") // gruvbox bright green
	colorWarn     = lipgloss.Color("#fe8019") // gruvbox bright orange
	colorErr      = lipgloss.Color("#fb4934") // gruvbox bright red
	colorSelected = lipgloss.Color("#ebdbb2") // gruvbox fg1
	colorDisabled = lipgloss.Color("#665c54") // gruvbox bg3

	titleStyle = lipgloss.NewStyle().Bold(true).Foreground(colorAccent)

	paneStyle = lipgloss.NewStyle().
			Border(lipgloss.RoundedBorder()).
			BorderForeground(colorMuted).
			Padding(0, 1)

	paneFocusedStyle = paneStyle.
				BorderForeground(colorAccent)

	labelStyle = lipgloss.NewStyle().Foreground(colorMuted)

	valueStyle = lipgloss.NewStyle().Foreground(colorSelected)

	focusedValueStyle = lipgloss.NewStyle().Foreground(colorSelected).Bold(true)

	mutedStyle = lipgloss.NewStyle().Foreground(colorMuted)

	okStyle   = lipgloss.NewStyle().Foreground(colorOK)
	warnStyle = lipgloss.NewStyle().Foreground(colorWarn)
	errStyle  = lipgloss.NewStyle().Foreground(colorErr)

	buttonStyle = lipgloss.NewStyle().Padding(0, 2).Foreground(colorMuted)

	buttonFocusedStyle = lipgloss.NewStyle().Padding(0, 2).
				Foreground(colorBg).
				Background(colorAccent).
				Bold(true)

	buttonDisabledStyle = lipgloss.NewStyle().Padding(0, 2).Foreground(colorDisabled)
)

func paneTitle(title string) string {
	return titleStyle.Render(title)
}

// tableStyles dresses the bubbles/table in the gruvbox palette: an accent header
// over a muted rule, fg cells, and a selected row that inverts to the accent so
// it reads the same as the focused buttons and borders.
func tableStyles() table.Styles {
	s := table.DefaultStyles()
	s.Header = s.Header.
		Foreground(colorAccent).
		BorderForeground(colorMuted).
		Bold(true)
	s.Cell = s.Cell.Foreground(colorSelected)
	s.Selected = s.Selected.
		Foreground(colorBg).
		Background(colorAccent).
		Bold(true)
	return s
}

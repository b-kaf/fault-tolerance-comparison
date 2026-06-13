package tui

import "github.com/charmbracelet/lipgloss"

// Palette and reusable styles for the TUI panes.
var (
	colorAccent   = lipgloss.Color("63")  // violet
	colorMuted    = lipgloss.Color("241") // grey
	colorOK       = lipgloss.Color("42")  // green
	colorWarn     = lipgloss.Color("214") // amber
	colorErr      = lipgloss.Color("203") // red
	colorSelected = lipgloss.Color("231") // near-white

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
				Foreground(lipgloss.Color("232")).
				Background(colorAccent).
				Bold(true)

	buttonDisabledStyle = lipgloss.NewStyle().Padding(0, 2).Foreground(lipgloss.Color("238"))
)

func paneTitle(title string) string {
	return titleStyle.Render(title)
}

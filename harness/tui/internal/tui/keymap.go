package tui

// Key handling is done with string switches in model.Update; this file
// documents the bindings and renders the help line.

const helpLine = "tab/↑↓ move · ←→ change · enter activate · esc stop · ctrl+c quit"

type focusHint int

const (
	hintDefault focusHint = iota
	hintActions
	hintResults
)

// helpForFocus tailors the hint to what's focused.
func helpForFocus(hint focusHint) string {
	switch hint {
	case hintActions:
		return "←→ pick action · enter activate · tab move · ctrl+c quit"
	case hintResults:
		return "↑↓ scroll rows · ←→ page columns · tab move · ctrl+c quit"
	default:
		return helpLine
	}
}

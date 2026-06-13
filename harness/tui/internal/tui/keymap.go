package tui

// Key handling is done with string switches in model.Update; this file
// documents the bindings and renders the help line.

const helpLine = "tab/↑↓ move · ←→ change · enter activate · esc stop · ctrl+c quit"

// helpForFocus tailors the hint to what's focused.
func helpForFocus(onActions bool) string {
	if onActions {
		return "←→ pick action · enter activate · tab move · ctrl+c quit"
	}
	return helpLine
}

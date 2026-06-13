package tui

import (
	"strings"

	"github.com/charmbracelet/bubbles/textinput"
	tea "github.com/charmbracelet/bubbletea"
)

type fieldKind int

const (
	selectKind fieldKind = iota
	textKind
)

// field is one configuration input: either a cycling select or a text input.
type field struct {
	label   string
	kind    fieldKind
	options []string        // selectKind
	index   int             // selectKind
	input   textinput.Model // textKind
}

func newSelect(label string, options []string, selected string) field {
	f := field{label: label, kind: selectKind, options: options}
	for i, o := range options {
		if o == selected {
			f.index = i
			break
		}
	}
	return f
}

func newText(label, value string) field {
	ti := textinput.New()
	ti.Prompt = ""
	ti.SetValue(value)
	ti.Width = 48
	return field{label: label, kind: textKind, input: ti}
}

func (f field) value() string {
	if f.kind == selectKind {
		if len(f.options) == 0 {
			return ""
		}
		return f.options[f.index]
	}
	return f.input.Value()
}

// setOptions replaces a select's choices, preserving the current selection if
// it survives, else falling back to the first option.
func (f *field) setOptions(options []string) {
	current := f.value()
	f.options = options
	f.index = 0
	for i, o := range options {
		if o == current {
			f.index = i
			break
		}
	}
}

func (f *field) cycle(delta int) {
	if f.kind != selectKind || len(f.options) == 0 {
		return
	}
	n := len(f.options)
	f.index = (f.index + delta%n + n) % n
}

func (f *field) focus() tea.Cmd {
	if f.kind == textKind {
		return f.input.Focus()
	}
	return nil
}

func (f *field) blur() {
	if f.kind == textKind {
		f.input.Blur()
	}
}

// view renders the field's value, highlighting it when focused.
func (f field) view(focused bool) string {
	switch f.kind {
	case selectKind:
		marker := "  "
		style := valueStyle
		if focused {
			marker = "‹ "
			style = focusedValueStyle
		}
		suffix := ""
		if focused {
			suffix = " ›"
		}
		return marker + style.Render(f.value()) + suffix
	default:
		return f.input.View()
	}
}

// labelWidth is the column width reserved for field labels.
const labelWidth = 12

func renderField(f field, focused bool) string {
	label := f.label
	if len(label) < labelWidth {
		label += strings.Repeat(" ", labelWidth-len(label))
	}
	cursor := "  "
	if focused {
		cursor = "▸ "
	}
	return cursor + labelStyle.Render(label) + f.view(focused)
}

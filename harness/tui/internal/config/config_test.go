package config

import "testing"

func TestParsePositiveInt(t *testing.T) {
	cases := []struct {
		in   string
		want int
		ok   bool
	}{
		{"20", 20, true},
		{"1", 1, true},
		{"010", 10, true}, // decimal with a leading zero, NOT octal 8
		{"0", 0, false},
		{"-5", 0, false},
		{"0x10", 0, false}, // hex is rejected, not parsed as 16
		{"abc", 0, false},
		{"", 0, false},
		{"99999999999999999999", 0, false}, // out of int range -> error, not truncation
	}
	for _, c := range cases {
		got, err := ParsePositiveInt(c.in)
		switch {
		case c.ok && (err != nil || got != c.want):
			t.Errorf("ParsePositiveInt(%q) = (%d, %v), want (%d, nil)", c.in, got, err, c.want)
		case !c.ok && err == nil:
			t.Errorf("ParsePositiveInt(%q) = (%d, nil), want an error", c.in, got)
		}
	}
}

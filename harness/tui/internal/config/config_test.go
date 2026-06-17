package config

import (
	"os"
	"path/filepath"
	"testing"
)

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

// A missing config.toml leaves every default in place.
func TestLoadSettingsMissingFileUsesDefaults(t *testing.T) {
	t.Setenv("QEMU_FT_FUZZ_PLUGIN", "")
	got, err := LoadSettings(t.TempDir())
	if err != nil {
		t.Fatalf("LoadSettings: %v", err)
	}
	if got != DefaultSettings() {
		t.Errorf("LoadSettings = %+v, want defaults %+v", got, DefaultSettings())
	}
}

// A present config.toml overrides only the keys it sets; omitted keys keep
// their defaults, and $QEMU_FT_FUZZ_PLUGIN wins over the file's plugin value.
func TestLoadSettingsMergesAndEnvOverridesPlugin(t *testing.T) {
	root := t.TempDir()
	dir := filepath.Join(root, "harness", "tui")
	if err := os.MkdirAll(dir, 0o755); err != nil {
		t.Fatal(err)
	}
	toml := "[e2e]\niterations = 5\n[fuzz]\nseed = \"0x1\"\nplugin = \"/from/file\"\n"
	if err := os.WriteFile(filepath.Join(dir, "config.toml"), []byte(toml), 0o644); err != nil {
		t.Fatal(err)
	}
	t.Setenv("QEMU_FT_FUZZ_PLUGIN", "/from/env")

	got, err := LoadSettings(root)
	if err != nil {
		t.Fatalf("LoadSettings: %v", err)
	}
	if got.E2E.Iterations != 5 {
		t.Errorf("iterations = %d, want 5 (from file)", got.E2E.Iterations)
	}
	if got.E2E.GdbPort != DefaultSettings().E2E.GdbPort {
		t.Errorf("gdb_port = %d, want the default %d (omitted in file)", got.E2E.GdbPort, DefaultSettings().E2E.GdbPort)
	}
	if got.Fuzz.Seed != "0x1" {
		t.Errorf("seed = %q, want \"0x1\" (from file)", got.Fuzz.Seed)
	}
	if got.Fuzz.Plugin != "/from/env" {
		t.Errorf("plugin = %q, want \"/from/env\" ($QEMU_FT_FUZZ_PLUGIN must override the file)", got.Fuzz.Plugin)
	}
}

// A malformed config.toml is a hard error, not a silent fallback to defaults.
func TestLoadSettingsMalformedErrors(t *testing.T) {
	root := t.TempDir()
	dir := filepath.Join(root, "harness", "tui")
	if err := os.MkdirAll(dir, 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(dir, "config.toml"), []byte("[e2e\nnope"), 0o644); err != nil {
		t.Fatal(err)
	}
	if _, err := LoadSettings(root); err == nil {
		t.Error("LoadSettings on malformed TOML = nil error, want a parse error")
	}
}

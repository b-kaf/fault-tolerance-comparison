// Package config carries run configuration for the e2e and fuzz engines and
// the Settings defaults loaded from harness/tui/config.toml. The Python CLIs
// took these from os.environ + python-dotenv; the Go port reads a single TOML
// file instead, falling back to baked-in defaults when it is absent.
package config

import (
	"fmt"
	"os"
	"path/filepath"
	"strconv"
	"time"

	"github.com/BurntSushi/toml"
)

const (
	GdbHost = "127.0.0.1"
	Gdb     = "gdb"
)

// E2E mirrors the injector's RunConfig.
type E2E struct {
	Iterations         int
	Technique          string
	Language           string
	Campaign           string
	CSV                string // empty = stdout
	Port               int
	ConnectTimeout     time.Duration
	StopTimeout        time.Duration
	QemuStartupTimeout time.Duration
	Elf                string
	Host               string
	Gdb                string
}

// Fuzz mirrors the fuzz runner's RunConfig. The campaign spec itself lives in
// the fuzz package; only the name travels here.
type Fuzz struct {
	Technique       string
	Language        string
	Campaign        string
	Trials          int
	Seed            uint64
	CSV             string // empty = stdout
	Timeout         time.Duration
	MaxInstructions uint64
	Plugin          string
	Elf             string
}

// Settings holds the tunable defaults previously supplied via .env / env vars.
// It is decoded from harness/tui/config.toml on top of DefaultSettings, so any
// key the file omits keeps its built-in default.
type Settings struct {
	E2E  E2ESettings  `toml:"e2e"`
	Fuzz FuzzSettings `toml:"fuzz"`
}

// E2ESettings are the e2e engine defaults. Timeouts are in seconds.
type E2ESettings struct {
	Iterations         int     `toml:"iterations"`
	GdbPort            int     `toml:"gdb_port"`
	ConnectTimeout     float64 `toml:"connect_timeout"`
	StopTimeout        float64 `toml:"stop_timeout"`
	QemuStartupTimeout float64 `toml:"qemu_startup_timeout"`
}

// FuzzSettings are the fuzz engine defaults. Seed is a base-0 string (so 0x
// hex is natural and the full u64 range is representable); Timeout is seconds.
type FuzzSettings struct {
	Trials          int     `toml:"trials"`
	Seed            string  `toml:"seed"`
	Timeout         float64 `toml:"timeout"`
	MaxInstructions uint64  `toml:"max_instructions"`
	Plugin          string  `toml:"plugin"`
}

// DefaultSettings are the built-in defaults, identical to the values the Python
// CLIs hard-coded as fallbacks. LoadSettings merges config.toml over these.
func DefaultSettings() Settings {
	return Settings{
		E2E: E2ESettings{
			Iterations:         20,
			GdbPort:            1234,
			ConnectTimeout:     10.0,
			StopTimeout:        10.0,
			QemuStartupTimeout: 10.0,
		},
		Fuzz: FuzzSettings{
			Trials:          20,
			Seed:            "0xc0dec0de",
			Timeout:         5.0,
			MaxInstructions: 1_000_000,
			Plugin:          "",
		},
	}
}

// ConfigPath is the location of the config file relative to the repo root.
func ConfigPath(repoRoot string) string {
	return filepath.Join(repoRoot, "harness", "tui", "config.toml")
}

// LoadSettings starts from DefaultSettings, decodes harness/tui/config.toml on
// top when present, then lets $QEMU_FT_FUZZ_PLUGIN override the plugin path so
// the Nix-built store path the devenv shell injects always wins. A missing
// file is not an error; a malformed one is.
func LoadSettings(repoRoot string) (Settings, error) {
	s := DefaultSettings()
	path := ConfigPath(repoRoot)
	if _, err := os.Stat(path); err == nil {
		if _, err := toml.DecodeFile(path, &s); err != nil {
			return s, fmt.Errorf("%s: %w", path, err)
		}
	}
	if v := os.Getenv("QEMU_FT_FUZZ_PLUGIN"); v != "" {
		s.Fuzz.Plugin = v
	}
	return s, nil
}

// Seconds converts a float seconds value (as stored in Settings) to a Duration.
func Seconds(f float64) time.Duration {
	return time.Duration(f * float64(time.Second))
}

// ParseU64 parses with base-0 semantics (0x.., 0o.., decimal) like int(s, 0).
func ParseU64(s string) (uint64, error) {
	v, err := strconv.ParseUint(s, 0, 64)
	if err != nil {
		return 0, fmt.Errorf("value must fit in u64: %q", s)
	}
	return v, nil
}

// ParsePositiveInt parses a plain decimal count (iterations/trials) and
// requires it to be positive. It uses Atoi rather than base-0 ParseInt so a
// field labelled "integer" does not silently treat "010" as octal or accept
// hex, and so an out-of-int-range value errors instead of truncating.
func ParsePositiveInt(s string) (int, error) {
	v, err := strconv.Atoi(s)
	if err != nil || v <= 0 {
		return 0, fmt.Errorf("value must be positive: %q", s)
	}
	return v, nil
}

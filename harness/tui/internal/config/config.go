// Package config carries run configuration for the e2e and fuzz engines and
// the env/.env defaulting that the Python CLIs got from os.environ +
// python-dotenv.
package config

import (
	"fmt"
	"os"
	"path/filepath"
	"strconv"
	"time"

	"github.com/joho/godotenv"
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

// LoadDotenv loads .env without overriding existing environment variables,
// matching load_dotenv(override=False). The Python CLIs ran from their own
// directories; we look in the current directory and the repo root.
func LoadDotenv(repoRoot string) {
	for _, dir := range []string{".", repoRoot} {
		path := filepath.Join(dir, ".env")
		if _, err := os.Stat(path); err == nil {
			_ = godotenv.Load(path)
		}
	}
}

// ParseU64 parses with base-0 semantics (0x.., 0o.., decimal) like int(s, 0).
func ParseU64(s string) (uint64, error) {
	v, err := strconv.ParseUint(s, 0, 64)
	if err != nil {
		return 0, fmt.Errorf("value must fit in u64: %q", s)
	}
	return v, nil
}

// ParsePositiveInt mirrors support.positive_int.
func ParsePositiveInt(s string) (int, error) {
	v, err := strconv.ParseInt(s, 0, 64)
	if err != nil || v <= 0 {
		return 0, fmt.Errorf("value must be positive: %q", s)
	}
	return int(v), nil
}

// EnvInt reads an integer env var with base-0 semantics, returning def when
// unset or empty.
func EnvInt(name string, def int64) (int64, error) {
	text := os.Getenv(name)
	if text == "" {
		return def, nil
	}
	v, err := strconv.ParseInt(text, 0, 64)
	if err != nil {
		return 0, fmt.Errorf("%s: %w", name, err)
	}
	return v, nil
}

// EnvU64 reads an unsigned integer env var with base-0 semantics.
func EnvU64(name string, def uint64) (uint64, error) {
	text := os.Getenv(name)
	if text == "" {
		return def, nil
	}
	v, err := strconv.ParseUint(text, 0, 64)
	if err != nil {
		return 0, fmt.Errorf("%s: %w", name, err)
	}
	return v, nil
}

// EnvSeconds reads a float env var expressing seconds, like the Python
// float(os.environ.get(...)) timeouts.
func EnvSeconds(name string, def float64) (time.Duration, error) {
	text := os.Getenv(name)
	if text == "" {
		return time.Duration(def * float64(time.Second)), nil
	}
	v, err := strconv.ParseFloat(text, 64)
	if err != nil {
		return 0, fmt.Errorf("%s: %w", name, err)
	}
	return time.Duration(v * float64(time.Second)), nil
}

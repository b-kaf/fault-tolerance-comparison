// Package run holds the config resolution shared by the headless CLI and the
// TUI: turning (technique, language, campaign, ...) plus env defaults into a
// validated config.E2E / config.Fuzz. It lives apart from config because it
// must import e2e and fuzz for their campaign rules, and config is imported
// by those packages.
package run

import (
	"fmt"
	"os"
	"slices"

	"github.com/b-kaf/fault-tolerance-comparison/harness/tui/internal/config"
	"github.com/b-kaf/fault-tolerance-comparison/harness/tui/internal/e2e"
	"github.com/b-kaf/fault-tolerance-comparison/harness/tui/internal/fuzz"
)

// Techniques and Languages are the accepted enum values, exposed so the TUI
// can populate its selects.
var (
	Techniques = []string{"tmr", "checkpoint", "recovery-block", "control-flow"}
	Languages  = []string{"c", "zig"}
)

func validEnum(list []string, value string) bool {
	return slices.Contains(list, value)
}

func resolveCommon(technique, language string) error {
	if !validEnum(Techniques, technique) {
		return fmt.Errorf("invalid --technique %q", technique)
	}
	if !validEnum(Languages, language) {
		return fmt.Errorf("--language is required and must be c or zig (got %q)", language)
	}
	return nil
}

// ResolveE2E validates inputs and fills env-derived defaults, returning a
// runnable config.E2E. An empty iterations (0) means "use the env default".
func ResolveE2E(repoRoot, technique, language, campaign string, iterations int, csvPath string) (config.E2E, error) {
	var cfg config.E2E
	if err := resolveCommon(technique, language); err != nil {
		return cfg, err
	}
	if campaign == "" {
		campaign = "mixed"
	}
	if !slices.Contains(e2e.CampaignChoices(), campaign) {
		return cfg, fmt.Errorf("invalid --campaign %q for e2e", campaign)
	}
	if msg := e2e.ValidateTechniqueCampaign(technique, campaign); msg != "" {
		return cfg, fmt.Errorf("%s", msg)
	}
	if iterations == 0 {
		v, err := config.EnvInt("HARNESS_E2E_ITERATIONS", 20)
		if err != nil {
			return cfg, err
		}
		iterations = int(v)
	}
	if iterations <= 0 {
		return cfg, fmt.Errorf("iterations must be positive")
	}

	port, err := config.EnvInt("HARNESS_E2E_GDB_PORT", 1234)
	if err != nil {
		return cfg, err
	}
	connectTimeout, err := config.EnvSeconds("HARNESS_E2E_CONNECT_TIMEOUT", 10.0)
	if err != nil {
		return cfg, err
	}
	stopTimeout, err := config.EnvSeconds("HARNESS_E2E_STOP_TIMEOUT", 10.0)
	if err != nil {
		return cfg, err
	}
	startupTimeout, err := config.EnvSeconds("HARNESS_E2E_QEMU_STARTUP_TIMEOUT", 10.0)
	if err != nil {
		return cfg, err
	}

	elf := config.E2EElfPath(repoRoot, technique, language)
	if _, err := os.Stat(elf); err != nil {
		return cfg, fmt.Errorf("inferred ELF not found: %s (run `zig build harness` first)", elf)
	}

	return config.E2E{
		Iterations:         iterations,
		Technique:          technique,
		Language:           language,
		Campaign:           campaign,
		CSV:                csvPath,
		Port:               int(port),
		ConnectTimeout:     connectTimeout,
		StopTimeout:        stopTimeout,
		QemuStartupTimeout: startupTimeout,
		Elf:                elf,
		Host:               config.GdbHost,
		Gdb:                config.Gdb,
	}, nil
}

// ResolveFuzz validates inputs and fills env-derived defaults, returning a
// runnable config.Fuzz. Empty trials (0) means "use the env default"; empty
// seedText means "use the env default".
func ResolveFuzz(repoRoot, technique, language, campaign string, trials int, seedText, csvPath string) (config.Fuzz, error) {
	var cfg config.Fuzz
	if err := resolveCommon(technique, language); err != nil {
		return cfg, err
	}
	if campaign == "" {
		campaign = "reg-bitflip"
	}
	if !slices.Contains(fuzz.CampaignChoices, campaign) {
		return cfg, fmt.Errorf("invalid --campaign %q for fuzz", campaign)
	}
	if trials == 0 {
		v, err := config.EnvInt("HARNESS_FUZZ_TRIALS", 20)
		if err != nil {
			return cfg, err
		}
		trials = int(v)
	}
	if trials <= 0 {
		return cfg, fmt.Errorf("trials must be positive")
	}

	var seed uint64
	if seedText != "" {
		v, err := config.ParseU64(seedText)
		if err != nil {
			return cfg, err
		}
		seed = v
	} else {
		v, err := config.EnvU64("HARNESS_FUZZ_SEED", 0xC0DEC0DE)
		if err != nil {
			return cfg, err
		}
		seed = v
	}

	timeout, err := config.EnvSeconds("HARNESS_FUZZ_TIMEOUT", 5.0)
	if err != nil {
		return cfg, err
	}
	maxInstructions, err := config.EnvU64("HARNESS_FUZZ_MAX_INSTRUCTIONS", 1_000_000)
	if err != nil {
		return cfg, err
	}

	plugin := os.Getenv("QEMU_FT_FUZZ_PLUGIN")
	if plugin == "" {
		return cfg, fmt.Errorf("QEMU_FT_FUZZ_PLUGIN is required in the environment or .env")
	}
	if _, err := os.Stat(plugin); err != nil {
		return cfg, fmt.Errorf("plugin not found: %s", plugin)
	}

	elf := config.FuzzElfPath(repoRoot, technique, language)
	if _, err := os.Stat(elf); err != nil {
		return cfg, fmt.Errorf("inferred ELF not found: %s (run `zig build fuzz-harness` first)", elf)
	}

	return config.Fuzz{
		Technique:       technique,
		Language:        language,
		Campaign:        campaign,
		Trials:          trials,
		Seed:            seed,
		CSV:             csvPath,
		Timeout:         timeout,
		MaxInstructions: maxInstructions,
		Plugin:          plugin,
		Elf:             elf,
	}, nil
}

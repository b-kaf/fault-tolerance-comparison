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
	Techniques = []string{"tmr", "checkpoint", "recovery-block", "control-flow", "combined", "baseline"}
	Languages  = []string{"c", "zig"}
)

// maxRunCount caps iterations/trials. These campaigns are slow (one QEMU run
// each), so any realistic count is far below this; the bound exists so an
// accidental huge value (typed in the TUI or passed on the CLI) is rejected
// cleanly instead of making the engine pre-allocate an absurd slice and panic.
const maxRunCount = 1_000_000

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

// ResolveE2E validates inputs and fills config-derived defaults, returning a
// runnable config.E2E. An empty iterations (0) means "use the config default".
func ResolveE2E(repoRoot string, s config.Settings, technique, language, campaign string, iterations int, csvPath string) (config.E2E, error) {
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
		iterations = s.E2E.Iterations
	}
	if iterations <= 0 {
		return cfg, fmt.Errorf("iterations must be positive")
	}
	if iterations > maxRunCount {
		return cfg, fmt.Errorf("iterations must be <= %d", maxRunCount)
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
		Port:               s.E2E.GdbPort,
		ConnectTimeout:     config.Seconds(s.E2E.ConnectTimeout),
		StopTimeout:        config.Seconds(s.E2E.StopTimeout),
		QemuStartupTimeout: config.Seconds(s.E2E.QemuStartupTimeout),
		Elf:                elf,
		Host:               config.GdbHost,
		Gdb:                config.Gdb,
	}, nil
}

// ResolveFuzz validates inputs and fills config-derived defaults, returning a
// runnable config.Fuzz. Empty trials (0) means "use the config default"; empty
// seedText means "use the config default".
func ResolveFuzz(repoRoot string, s config.Settings, technique, language, campaign string, trials int, seedText, csvPath string) (config.Fuzz, error) {
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
		trials = s.Fuzz.Trials
	}
	if trials <= 0 {
		return cfg, fmt.Errorf("trials must be positive")
	}
	if trials > maxRunCount {
		return cfg, fmt.Errorf("trials must be <= %d", maxRunCount)
	}

	if seedText == "" {
		seedText = s.Fuzz.Seed
	}
	seed, err := config.ParseU64(seedText)
	if err != nil {
		return cfg, err
	}

	plugin := s.Fuzz.Plugin
	if plugin == "" {
		return cfg, fmt.Errorf("fuzz plugin path is unset: set QEMU_FT_FUZZ_PLUGIN or [fuzz].plugin in %s", config.ConfigPath(repoRoot))
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
		Timeout:         config.Seconds(s.Fuzz.Timeout),
		MaxInstructions: s.Fuzz.MaxInstructions,
		Plugin:          plugin,
		Elf:             elf,
	}, nil
}

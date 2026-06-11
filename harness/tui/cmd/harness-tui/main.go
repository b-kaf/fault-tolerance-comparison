package main

import (
	"flag"
	"fmt"
	"os"

	"github.com/b-kaf/fault-tolerance-comparison/harness/tui/internal/config"
)

var techniques = map[string]bool{
	"tmr":            true,
	"checkpoint":     true,
	"recovery-block": true,
	"control-flow":   true,
}

var languages = map[string]bool{
	"c":   true,
	"zig": true,
}

func main() {
	os.Exit(run())
}

func run() int {
	headless := flag.Bool("headless", false, "run without the TUI (scripted/CI mode)")
	mode := flag.String("mode", "", "engine to drive in headless mode: e2e | fuzz")
	technique := flag.String("technique", "tmr", "harness technique: tmr | checkpoint | recovery-block | control-flow")
	language := flag.String("language", "", "harness implementation language: c | zig")
	campaign := flag.String("campaign", "", "campaign name (default: mixed for e2e, reg-bitflip for fuzz)")
	iterations := flag.Int("iterations", 0, "e2e iteration count (default: $HARNESS_E2E_ITERATIONS or 20)")
	trials := flag.Int("trials", 0, "fuzz trial count (default: $HARNESS_FUZZ_TRIALS or 20)")
	seed := flag.String("seed", "", "fuzz campaign seed, u64 (default: $HARNESS_FUZZ_SEED or 0xC0DEC0DE)")
	csvPath := flag.String("csv", "", "write results to this CSV path instead of stdout (headless)")
	flag.Parse()

	cwd, err := os.Getwd()
	if err != nil {
		return fail(err)
	}
	repoRoot, err := config.FindRepoRoot(cwd)
	if err != nil {
		return fail(err)
	}
	config.LoadDotenv(repoRoot)

	if !*headless {
		fmt.Println("harness-tui: TUI not implemented yet (phase 5); use --headless")
		return 2
	}

	switch *mode {
	case "e2e":
		cfg, err := resolveE2E(repoRoot, *technique, *language, *campaign, *iterations, *csvPath)
		if err != nil {
			return fail(err)
		}
		fmt.Fprintf(os.Stderr, "harness-tui: e2e engine not implemented yet (phase 4); config resolved: %+v\n", cfg)
		return 2
	case "fuzz":
		cfg, err := resolveFuzz(repoRoot, *technique, *language, *campaign, *trials, *seed, *csvPath)
		if err != nil {
			return fail(err)
		}
		fmt.Fprintf(os.Stderr, "harness-tui: fuzz engine not implemented yet (phase 3); config resolved: %+v\n", cfg)
		return 2
	default:
		return fail(fmt.Errorf("--headless requires --mode e2e or --mode fuzz"))
	}
}

func resolveCommon(technique, language string) error {
	if !techniques[technique] {
		return fmt.Errorf("invalid --technique %q", technique)
	}
	if !languages[language] {
		return fmt.Errorf("--language is required and must be c or zig (got %q)", language)
	}
	return nil
}

func resolveE2E(repoRoot, technique, language, campaign string, iterations int, csvPath string) (config.E2E, error) {
	var cfg config.E2E
	if err := resolveCommon(technique, language); err != nil {
		return cfg, err
	}
	if campaign == "" {
		campaign = "mixed"
	}
	if iterations == 0 {
		v, err := config.EnvInt("HARNESS_E2E_ITERATIONS", 20)
		if err != nil {
			return cfg, err
		}
		iterations = int(v)
	}
	if iterations <= 0 {
		return cfg, fmt.Errorf("--iterations must be positive")
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

func resolveFuzz(repoRoot, technique, language, campaign string, trials int, seedText, csvPath string) (config.Fuzz, error) {
	var cfg config.Fuzz
	if err := resolveCommon(technique, language); err != nil {
		return cfg, err
	}
	if campaign == "" {
		campaign = "reg-bitflip"
	}
	if trials == 0 {
		v, err := config.EnvInt("HARNESS_FUZZ_TRIALS", 20)
		if err != nil {
			return cfg, err
		}
		trials = int(v)
	}
	if trials <= 0 {
		return cfg, fmt.Errorf("--trials must be positive")
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

func fail(err error) int {
	fmt.Fprintf(os.Stderr, "harness-tui: %v\n", err)
	return 2
}

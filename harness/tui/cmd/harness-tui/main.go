package main

import (
	"context"
	"flag"
	"fmt"
	"os"

	"github.com/b-kaf/fault-tolerance-comparison/harness/tui/internal/config"
	"github.com/b-kaf/fault-tolerance-comparison/harness/tui/internal/e2e"
	"github.com/b-kaf/fault-tolerance-comparison/harness/tui/internal/fuzz"
	"github.com/b-kaf/fault-tolerance-comparison/harness/tui/internal/run"
	"github.com/b-kaf/fault-tolerance-comparison/harness/tui/internal/tui"
)

func main() {
	os.Exit(main2())
}

func main2() int {
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
		if err := tui.Run(repoRoot); err != nil {
			return fail(err)
		}
		return 0
	}

	switch *mode {
	case "e2e":
		cfg, err := run.ResolveE2E(repoRoot, *technique, *language, *campaign, *iterations, *csvPath)
		if err != nil {
			return fail(err)
		}
		summary, err := e2e.Run(context.Background(), cfg, e2e.Events{})
		if err != nil {
			return fail(err)
		}
		if cfg.CSV != "" {
			fmt.Printf("wrote %s (%d iterations, passes=%d failures=%d)\n",
				cfg.CSV, summary.Iterations, summary.Passes, summary.Failures)
		}
		if summary.Success() {
			return 0
		}
		return 1
	case "fuzz":
		cfg, err := run.ResolveFuzz(repoRoot, *technique, *language, *campaign, *trials, *seed, *csvPath)
		if err != nil {
			return fail(err)
		}
		summary, err := fuzz.Run(context.Background(), cfg, os.Stderr, fuzz.Events{})
		if err != nil {
			return fail(err)
		}
		if cfg.CSV == "" {
			fmt.Fprintf(os.Stderr, "summary: %s\n", summary)
		} else {
			fmt.Printf("wrote %s (%s)\n", cfg.CSV, summary)
		}
		return 0
	default:
		return fail(fmt.Errorf("--headless requires --mode e2e or --mode fuzz"))
	}
}

func fail(err error) int {
	fmt.Fprintf(os.Stderr, "harness-tui: %v\n", err)
	return 2
}

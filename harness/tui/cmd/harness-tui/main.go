package main

import (
	"context"
	"errors"
	"fmt"
	"os"

	"github.com/alecthomas/kong"

	"github.com/b-kaf/fault-tolerance-comparison/harness/tui/internal/config"
	"github.com/b-kaf/fault-tolerance-comparison/harness/tui/internal/e2e"
	"github.com/b-kaf/fault-tolerance-comparison/harness/tui/internal/fuzz"
	"github.com/b-kaf/fault-tolerance-comparison/harness/tui/internal/result"
	"github.com/b-kaf/fault-tolerance-comparison/harness/tui/internal/run"
	"github.com/b-kaf/fault-tolerance-comparison/harness/tui/internal/tui"
)

// Exit codes are part of the CLI contract CI depends on (see PLAN.md): a clean
// e2e campaign exits 0, one that runs but ends with a non-zero failure counter
// exits 1, and any bad input / usage error / hard run error exits 2.
const (
	exitOK       = 0
	exitFailures = 1
	exitError    = 2
)

// errFailures marks an e2e campaign that completed without error but whose
// outcome is a failure. It maps to exitFailures and is not reported as an error.
var errFailures = errors.New("campaign completed with failures")

// CLI is the kong grammar. Each command is its own subcommand with its own
// flags; tui is the default so a bare `harness-tui` still opens the UI.
type CLI struct {
	TUI  tuiCmd  `cmd:"" name:"tui" default:"1" help:"Launch the interactive TUI (default when no command is given)."`
	E2E  e2eCmd  `cmd:"" name:"e2e" help:"Run an end-to-end GDB fault-injection campaign without the TUI."`
	Fuzz fuzzCmd `cmd:"" name:"fuzz" help:"Run a QEMU-plugin fuzzing campaign without the TUI."`
}

// env is resolved once and injected into each command's Run by kong.
type env struct {
	repoRoot string
	settings config.Settings
}

type tuiCmd struct{}

func (c *tuiCmd) Run(e *env) error {
	return tui.Run(e.repoRoot, e.settings)
}

type e2eCmd struct {
	Technique  string `help:"Harness technique." enum:"tmr,checkpoint,recovery-block,control-flow" default:"tmr"`
	Language   string `help:"Harness implementation language." enum:"c,zig" required:""`
	Campaign   string `help:"Campaign name." default:"mixed"`
	Iterations int    `help:"Iteration count (0 = the config.toml [e2e].iterations default)." default:"0"`
	CSV        string `help:"Write results to this CSV path instead of stdout." placeholder:"PATH"`
}

func (c *e2eCmd) Run(e *env) error {
	cfg, err := run.ResolveE2E(e.repoRoot, e.settings, c.Technique, c.Language, c.Campaign, c.Iterations, c.CSV)
	if err != nil {
		return err
	}
	summary, rows, err := e2e.Run(context.Background(), cfg, e2e.Events{})
	if err != nil {
		return err
	}
	if err := result.WriteE2ECSV(cfg.CSV, rows); err != nil {
		return err
	}
	if cfg.CSV != "" {
		fmt.Printf("wrote %s (%d iterations, passes=%d failures=%d)\n",
			cfg.CSV, summary.Iterations, summary.Passes, summary.Failures)
	}
	if !summary.Success() {
		return errFailures
	}
	return nil
}

type fuzzCmd struct {
	Technique string `help:"Harness technique." enum:"tmr,checkpoint,recovery-block,control-flow" default:"tmr"`
	Language  string `help:"Harness implementation language." enum:"c,zig" required:""`
	Campaign  string `help:"Campaign name." default:"reg-bitflip"`
	Trials    int    `help:"Trial count (0 = the config.toml [fuzz].trials default)." default:"0"`
	Seed      string `help:"Campaign seed, u64 (empty = the config.toml [fuzz].seed default)."`
	CSV       string `help:"Write results to this CSV path instead of stdout." placeholder:"PATH"`
}

func (c *fuzzCmd) Run(e *env) error {
	cfg, err := run.ResolveFuzz(e.repoRoot, e.settings, c.Technique, c.Language, c.Campaign, c.Trials, c.Seed, c.CSV)
	if err != nil {
		return err
	}
	summary, rows, err := fuzz.Run(context.Background(), cfg, os.Stderr, fuzz.Events{})
	if err != nil {
		return err
	}
	if err := result.WriteFuzzCSV(cfg.CSV, rows); err != nil {
		return err
	}
	if cfg.CSV == "" {
		fmt.Fprintf(os.Stderr, "summary: %s\n", summary)
	} else {
		fmt.Printf("wrote %s (%s)\n", cfg.CSV, summary)
	}
	return nil
}

func main() {
	os.Exit(realMain())
}

func realMain() int {
	var cli CLI
	parser, err := kong.New(&cli,
		kong.Name("harness-tui"),
		kong.Description("Fault-tolerance harness runner: an interactive TUI plus headless e2e/fuzz campaigns."),
	)
	if err != nil {
		return fail(err) // a malformed grammar is a programmer error
	}
	kctx, err := parser.Parse(os.Args[1:])
	if err != nil {
		// Show context-sensitive usage on a parse error, then exit 2 (kong's
		// own default would exit 1, which we reserve for e2e failures).
		var pe *kong.ParseError
		if errors.As(err, &pe) && pe.Context != nil {
			_ = pe.Context.PrintUsage(false)
		}
		return fail(err)
	}

	e, err := newEnv()
	if err != nil {
		return fail(err)
	}

	switch err := kctx.Run(e); {
	case err == nil:
		return exitOK
	case errors.Is(err, errFailures):
		return exitFailures
	default:
		return fail(err)
	}
}

// newEnv resolves the repo root and loads harness/tui/config.toml once, before
// any command runs.
func newEnv() (*env, error) {
	cwd, err := os.Getwd()
	if err != nil {
		return nil, err
	}
	repoRoot, err := config.FindRepoRoot(cwd)
	if err != nil {
		return nil, err
	}
	settings, err := config.LoadSettings(repoRoot)
	if err != nil {
		return nil, err
	}
	return &env{repoRoot: repoRoot, settings: settings}, nil
}

func fail(err error) int {
	fmt.Fprintf(os.Stderr, "harness-tui: %v\n", err)
	return exitError
}

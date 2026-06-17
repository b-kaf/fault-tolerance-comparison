package e2e

import (
	"context"
	"fmt"

	"github.com/b-kaf/fault-tolerance-comparison/harness/tui/internal/config"
	"github.com/b-kaf/fault-tolerance-comparison/harness/tui/internal/gdbmi"
	"github.com/b-kaf/fault-tolerance-comparison/harness/tui/internal/qemu"
	"github.com/b-kaf/fault-tolerance-comparison/harness/tui/internal/result"
)

// Events carries optional engine callbacks for the TUI; all fields may be
// nil. OnIteration fires after each iteration's row is collected.
type Events struct {
	OnIteration func(iteration, total int, row result.Row)
}

// Summary reports a finished (or cancelled) campaign. Passes/Failures are the
// cumulative counters read on the last iteration.
type Summary struct {
	Iterations int
	Passes     uint32
	Failures   uint32
}

// Success mirrors the Python exit code: 0 when at least one iteration ran and
// the final failure counter is zero.
func (s Summary) Success() bool {
	return s.Iterations > 0 && s.Failures == 0
}

// Run drives a GDB fault-injection campaign: start QEMU halted with a gdbstub,
// attach, install the technique's breakpoints, then loop continue/read/inject/
// continue/read. It collects the per-iteration rows in memory and returns them;
// persisting them to CSV is the caller's choice (the headless CLI writes them,
// the TUI exports on demand). On ctx cancellation (TUI Stop) the rows gathered
// so far are returned alongside ctx.Err(); a hard error returns them too so a
// partial campaign is never silently dropped.
func Run(ctx context.Context, cfg config.E2E, events Events) (Summary, []result.Row, error) {
	var summary Summary

	argv := append(qemu.BaseCommand(qemu.Binary, cfg.Elf),
		"-S", "-gdb", fmt.Sprintf("tcp::%d", cfg.Port))
	proc, err := qemu.Start(argv)
	if err != nil {
		return summary, nil, err
	}
	defer proc.Terminate(cfg.StopTimeout)

	if err := qemu.WaitForGdbPort(proc, cfg.Host, cfg.Port, cfg.QemuStartupTimeout); err != nil {
		return summary, nil, err
	}

	client, err := gdbmi.New(gdbmi.Config{
		Gdb:            cfg.Gdb,
		Elf:            cfg.Elf,
		Host:           cfg.Host,
		Port:           cfg.Port,
		ConnectTimeout: cfg.ConnectTimeout,
		StopTimeout:    cfg.StopTimeout,
	})
	if err != nil {
		return summary, nil, err
	}
	defer client.Close()

	breakpoints, err := client.InstallBreakpoints(cfg.Technique)
	if err != nil {
		return summary, nil, err
	}

	rows := make([]result.Row, 0, cfg.Iterations)
	for i := 0; i < cfg.Iterations; i++ {
		row, err := runIteration(ctx, client, cfg, breakpoints)
		if err != nil {
			// Return whatever we gathered (possibly empty) so the caller can
			// still keep a partial campaign; a cancellation is surfaced as
			// ctx.Err() so callers classify it as a deliberate stop.
			summary = finalize(rows)
			if ctx.Err() != nil {
				return summary, rows, ctx.Err()
			}
			return summary, rows, err
		}
		rows = append(rows, row)
		if events.OnIteration != nil {
			events.OnIteration(i+1, cfg.Iterations, row)
		}
	}

	summary = finalize(rows)
	return summary, rows, nil
}

// runIteration performs one continue/read/inject/continue/read cycle,
// dispatching the technique-specific fault choice and row build.
func runIteration(ctx context.Context, client *gdbmi.Client, cfg config.E2E, bp gdbmi.Breakpoints) (result.Row, error) {
	if _, err := client.ContinueUntilBreakpoint(ctx, bp.Inject); err != nil {
		return nil, err
	}
	iteration, err := client.ReadU32("harness_iteration")
	if err != nil {
		return nil, err
	}

	var expected uint32
	var chosen fault
	if cfg.Technique == "tmr" {
		expected, err = client.ReadU32("harness_last_expected")
		if err != nil {
			return nil, err
		}
		chosen = chooseTMRFault(cfg.Campaign, iteration, expected)
	} else {
		chosen = chooseFault(cfg.Technique, cfg.Campaign, iteration)
	}

	if err := client.WriteU32("harness_fault_value", chosen.value); err != nil {
		return nil, err
	}
	if err := client.WriteU32("harness_fault_target", chosen.target); err != nil {
		return nil, err
	}

	if _, err := client.ContinueUntilBreakpoint(ctx, bp.Observe); err != nil {
		return nil, err
	}

	switch cfg.Technique {
	case "checkpoint":
		return checkpointRow(client, cfg.Campaign, cfg.Language, iteration, chosen)
	case "recovery-block":
		return recoveryBlockRow(client, cfg.Campaign, cfg.Language, iteration, chosen)
	case "control-flow":
		return controlFlowRow(client, cfg.Campaign, cfg.Language, iteration, chosen)
	case "combined":
		return combinedRow(client, cfg.Campaign, cfg.Language, iteration, chosen)
	case "baseline":
		return baselineRow(client, cfg.Campaign, cfg.Language, iteration, chosen)
	default:
		return tmrRow(client, cfg.Campaign, cfg.Language, iteration, expected, chosen)
	}
}

func chooseFault(technique, campaign string, iteration uint32) fault {
	switch technique {
	case "checkpoint":
		return chooseCheckpointFault(campaign, iteration)
	case "recovery-block":
		return chooseRecoveryBlockFault(campaign, iteration)
	case "control-flow":
		return chooseControlFlowFault(campaign, iteration)
	case "combined", "baseline":
		return chooseWorkflowFault(campaign, iteration)
	default:
		return fault{}
	}
}

func finalize(rows []result.Row) Summary {
	summary := Summary{Iterations: len(rows)}
	if len(rows) > 0 {
		last := rows[len(rows)-1]
		summary.Passes, _ = last["passes"].(uint32)
		summary.Failures, _ = last["failures"].(uint32)
	}
	return summary
}

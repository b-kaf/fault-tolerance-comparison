package fuzz

import (
	"context"
	"fmt"
	"io"
	"strings"
	"time"

	"github.com/b-kaf/fault-tolerance-comparison/harness/tui/internal/qemu"
	"github.com/b-kaf/fault-tolerance-comparison/harness/tui/internal/target"
)

// ProcessResult mirrors runner.ProcessResult. Stderr is everything the QEMU
// child wrote to stderr, which carries the plugin's @@FT result record.
type ProcessResult struct {
	ProcessStatus string
	Timeout       bool
	ElapsedMS     int64
	Stderr        string
}

const terminateTimeout = 2 * time.Second

// resultSentinel marks a complete @@FT result record on the plugin's stderr;
// its appearance is the completion signal (the plugin keeps QEMU running, so
// the runner terminates the process once it sees this).
const resultSentinel = "@@FT-END"

// RunQemuTrial mirrors runner.run_qemu_trial: launch QEMU with the plugin,
// poll for the done flag (checked before process exit, since QEMU keeps
// running after the plugin writes it), and classify how the process ended.
// Cancelling ctx terminates the trial early with status "cancelled".
//
// oneInsnPerTB appends -accel tcg,one-insn-per-tb=on, required by the insn-skip
// campaign so a mid-TB PC write removes exactly one instruction; it is gated
// per-campaign because it slows emulation and other modes do not need it.
func RunQemuTrial(ctx context.Context, profile target.Profile, elfPath, plugin, manifest string, pluginArgs []string, timeout time.Duration, oneInsnPerTB bool, warnings io.Writer) (ProcessResult, error) {
	pluginSpec := fmt.Sprintf("file=%s,manifest=%s", plugin, manifest)
	if len(pluginArgs) > 0 {
		pluginSpec += "," + strings.Join(pluginArgs, ",")
	}
	argv := qemu.BaseCommand(profile, elfPath)
	// -accel must precede -plugin: on RISC-V, configuring one-insn-per-tb after
	// the plugin loads leaves the plugin's vcpu_init register enumeration empty
	// (no pc handle), breaking insn-skip. ARM tolerates either order.
	if oneInsnPerTB {
		argv = append(argv, "-accel", "tcg,one-insn-per-tb=on")
	}
	argv = append(argv, "-plugin", pluginSpec)

	start := time.Now()
	proc, err := qemu.Start(argv)
	if err != nil {
		return ProcessResult{}, err
	}
	defer func() {
		if !proc.Exited() {
			proc.Terminate(terminateTimeout)
		}
	}()

	deadline := start.Add(timeout)
	for time.Now().Before(deadline) {
		if ctx.Err() != nil {
			proc.Terminate(terminateTimeout)
			return ProcessResult{
				ProcessStatus: "cancelled",
				Timeout:       false,
				ElapsedMS:     time.Since(start).Milliseconds(),
				Stderr:        proc.Stderr(),
			}, ctx.Err()
		}
		if strings.Contains(proc.Stderr(), resultSentinel) {
			proc.Terminate(terminateTimeout)
			return ProcessResult{
				ProcessStatus: "completed",
				Timeout:       false,
				ElapsedMS:     time.Since(start).Milliseconds(),
				Stderr:        proc.Stderr(),
			}, nil
		}
		if proc.Exited() {
			status := proc.ExitCode()
			warnOnStderr(warnings, proc, fmt.Sprintf("qemu exited with status %d", status))
			return ProcessResult{
				ProcessStatus: fmt.Sprintf("exit:%d", status),
				Timeout:       false,
				ElapsedMS:     time.Since(start).Milliseconds(),
				Stderr:        proc.Stderr(),
			}, nil
		}
		time.Sleep(20 * time.Millisecond)
	}

	proc.Terminate(terminateTimeout)
	warnOnStderr(warnings, proc, "qemu timed out")
	return ProcessResult{
		ProcessStatus: "timeout",
		Timeout:       true,
		ElapsedMS:     time.Since(start).Milliseconds(),
		Stderr:        proc.Stderr(),
	}, nil
}

func warnOnStderr(warnings io.Writer, proc *qemu.Process, reason string) {
	if warnings == nil {
		return
	}
	stderr := strings.TrimSpace(proc.Stderr())
	if stderr != "" {
		fmt.Fprintf(warnings, "warning: %s; qemu stderr:\n%s\n", reason,
			strings.TrimRight(proc.Stderr(), "\n"))
	}
}

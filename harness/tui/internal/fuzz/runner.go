package fuzz

import (
	"context"
	"fmt"
	"io"
	"os"
	"strings"
	"time"

	"github.com/b-kaf/fault-tolerance-comparison/harness/tui/internal/qemu"
)

// ProcessResult mirrors runner.ProcessResult.
type ProcessResult struct {
	ProcessStatus string
	Timeout       bool
	ElapsedMS     int64
}

const terminateTimeout = 2 * time.Second

// RunQemuTrial mirrors runner.run_qemu_trial: launch QEMU with the plugin,
// poll for the done flag (checked before process exit, since QEMU keeps
// running after the plugin writes it), and classify how the process ended.
// Cancelling ctx terminates the trial early with status "cancelled".
func RunQemuTrial(ctx context.Context, qemuBin, elfPath, plugin, manifest, done string, timeout time.Duration, warnings io.Writer) (ProcessResult, error) {
	argv := append(qemu.BaseCommand(qemuBin, elfPath),
		"-plugin", fmt.Sprintf("file=%s,manifest=%s", plugin, manifest))

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
			}, ctx.Err()
		}
		if _, err := os.Stat(done); err == nil {
			proc.Terminate(terminateTimeout)
			return ProcessResult{
				ProcessStatus: "completed",
				Timeout:       false,
				ElapsedMS:     time.Since(start).Milliseconds(),
			}, nil
		}
		if proc.Exited() {
			status := proc.ExitCode()
			warnOnStderr(warnings, proc, fmt.Sprintf("qemu exited with status %d", status))
			return ProcessResult{
				ProcessStatus: fmt.Sprintf("exit:%d", status),
				Timeout:       false,
				ElapsedMS:     time.Since(start).Milliseconds(),
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

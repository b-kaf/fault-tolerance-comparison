// Package qemu builds the mps2-an386 command line and owns child process
// lifecycle: start with captured stderr, detect exit, and the
// SIGTERM-then-wait-then-SIGKILL shutdown from support.terminate_process.
package qemu

import (
	"bytes"
	"fmt"
	"net"
	"os/exec"
	"strconv"
	"sync"
	"syscall"
	"time"
)

const (
	Binary  = "qemu-system-arm"
	machine = "mps2-an386"
	cpu     = "cortex-m4"
)

// BaseCommand mirrors support.qemu_mps2_an386_command.
func BaseCommand(qemu, elf string) []string {
	return []string{
		qemu,
		"-M", machine,
		"-cpu", cpu,
		"-kernel", elf,
		"-nographic",
		"-monitor", "none",
		"-serial", "none",
	}
}

// Process wraps a started child with captured stderr and a single reaper, so
// exit checks and termination never race on Wait.
type Process struct {
	cmd  *exec.Cmd
	done chan struct{}

	mu     sync.Mutex
	stderr bytes.Buffer
}

// Start launches argv with stdout discarded and stderr captured.
func Start(argv []string) (*Process, error) {
	cmd := exec.Command(argv[0], argv[1:]...)
	p := &Process{cmd: cmd, done: make(chan struct{})}
	cmd.Stdout = nil
	cmd.Stderr = lockedWriter{p}
	if err := cmd.Start(); err != nil {
		return nil, err
	}
	go func() {
		_ = cmd.Wait()
		close(p.done)
	}()
	return p, nil
}

type lockedWriter struct{ p *Process }

func (w lockedWriter) Write(b []byte) (int, error) {
	w.p.mu.Lock()
	defer w.p.mu.Unlock()
	return w.p.stderr.Write(b)
}

// Done is closed once the child has been reaped.
func (p *Process) Done() <-chan struct{} { return p.done }

// Exited reports whether the child has terminated.
func (p *Process) Exited() bool {
	select {
	case <-p.done:
		return true
	default:
		return false
	}
}

// ExitCode is only meaningful after the process exited.
func (p *Process) ExitCode() int {
	return p.cmd.ProcessState.ExitCode()
}

// Stderr returns everything the child wrote to stderr so far.
func (p *Process) Stderr() string {
	p.mu.Lock()
	defer p.mu.Unlock()
	return p.stderr.String()
}

// Terminate mirrors support.terminate_process: SIGTERM, wait, SIGKILL, wait.
func (p *Process) Terminate(timeout time.Duration) {
	if p.Exited() {
		return
	}
	_ = p.cmd.Process.Signal(syscall.SIGTERM)
	select {
	case <-p.done:
		return
	case <-time.After(timeout):
	}
	_ = p.cmd.Process.Kill()
	select {
	case <-p.done:
	case <-time.After(timeout):
	}
}

// WaitForGdbPort polls until the child opens its GDB TCP port, mirroring the
// injector's wait_for_gdb_port: fail fast if QEMU exits early, otherwise
// retry connecting until the deadline.
func WaitForGdbPort(p *Process, host string, port int, timeout time.Duration) error {
	address := net.JoinHostPort(host, strconv.Itoa(port))
	deadline := time.Now().Add(timeout)
	for time.Now().Before(deadline) {
		if p.Exited() {
			return fmt.Errorf("QEMU exited early with status %d\n%s",
				p.ExitCode(), p.Stderr())
		}
		conn, err := net.DialTimeout("tcp", address, 250*time.Millisecond)
		if err == nil {
			conn.Close()
			return nil
		}
		time.Sleep(25 * time.Millisecond)
	}
	return fmt.Errorf("QEMU did not open GDB port %s within %.1fs",
		address, timeout.Seconds())
}

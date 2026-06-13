// Package gdbmi wraps github.com/cyrus-and/gdb with the behaviour the Python
// pygdbmi client gave us: per-command timeouts, a stop-wait channel fed by
// async *stopped records, and u32 read/write helpers. The library owns MI2
// record parsing; this package adds the timeout/cancellation story it lacks.
package gdbmi

import (
	"context"
	"fmt"
	"strconv"
	"strings"
	"time"

	"github.com/cyrus-and/gdb"
)

// Config carries the connection parameters mirroring injector RunConfig.
type Config struct {
	Gdb            string
	Elf            string
	Host           string
	Port           int
	ConnectTimeout time.Duration
	StopTimeout    time.Duration
}

// commandTimeout bounds synchronous MI commands on a halted target. The
// Python client used a 5s default for everything except connect.
const commandTimeout = 5 * time.Second

// Client is a thin, timeout-aware wrapper over a gdb --interpreter=mi2
// subprocess connected to a remote target.
type Client struct {
	gdb         *gdb.Gdb
	stopTimeout time.Duration
	cmdTimeout  time.Duration
	// stops carries *stopped payloads from the record-reader goroutine. It is
	// buffered and written non-blocking so the reader never wedges; the serial
	// continue/stop flow drains it before each continue.
	stops chan map[string]any
}

// New starts gdb, configures it, and connects to the remote target. It
// mirrors GdbMi.__init__'s command sequence exactly.
func New(cfg Config) (*Client, error) {
	c := &Client{
		stopTimeout: cfg.StopTimeout,
		cmdTimeout:  commandTimeout,
		stops:       make(chan map[string]any, 8),
	}

	command := []string{cfg.Gdb, "--interpreter=mi2", "--nx", "--quiet"}
	instance, err := gdb.NewCmd(command, c.onNotification)
	if err != nil {
		return nil, err
	}
	c.gdb = instance

	if err := c.setup(cfg); err != nil {
		c.Close()
		return nil, err
	}
	return c, nil
}

func (c *Client) setup(cfg Config) error {
	if _, err := c.checkedSend(c.cmdTimeout, "file-exec-and-symbols", cfg.Elf); err != nil {
		return err
	}
	if _, err := c.checkedSend(c.cmdTimeout, "gdb-set", "confirm", "off"); err != nil {
		return err
	}
	if _, err := c.checkedSend(c.cmdTimeout, "gdb-set", "pagination", "off"); err != nil {
		return err
	}
	// set architecture is best-effort, matching allow_error=True.
	if _, err := c.send(c.cmdTimeout, "interpreter-exec", "console", "set architecture armv7e-m"); err != nil {
		return err
	}
	target := fmt.Sprintf("%s:%d", cfg.Host, cfg.Port)
	if _, err := c.checkedSend(cfg.ConnectTimeout, "target-select", "remote", target); err != nil {
		return err
	}
	return nil
}

// onNotification runs on the library's record-reader goroutine. It forwards
// *stopped payloads and drops everything else.
func (c *Client) onNotification(notification map[string]any) {
	if notification["type"] != "exec" || notification["class"] != "stopped" {
		return
	}
	payload, _ := notification["payload"].(map[string]any)
	if payload == nil {
		payload = map[string]any{}
	}
	select {
	case c.stops <- payload:
	default: // serial flow never has more than one outstanding stop
	}
}

// InsertHardwareBreakpoint installs a hardware breakpoint on symbol and
// returns its MI number, mirroring _insert_breakpoint (-break-insert -h).
func (c *Client) InsertHardwareBreakpoint(symbol string) (string, error) {
	record, err := c.checkedSend(c.cmdTimeout, "break-insert", "-h", symbol)
	if err != nil {
		return "", err
	}
	payload, _ := record["payload"].(map[string]any)
	bkpt, _ := payload["bkpt"].(map[string]any)
	number, ok := bkpt["number"].(string)
	if !ok {
		return "", fmt.Errorf("could not install breakpoint for %s: %v", symbol, record)
	}
	return number, nil
}

// ContinueUntilBreakpoint resumes the target and waits for it to stop at the
// expected breakpoint, mirroring continue_until_breakpoint. ctx cancellation
// (TUI Stop) aborts the wait promptly.
func (c *Client) ContinueUntilBreakpoint(ctx context.Context, breakpointNumber string) (map[string]any, error) {
	c.drainStops()
	if _, err := c.checkedSend(c.cmdTimeout, "exec-continue"); err != nil {
		return nil, err
	}

	select {
	case stop := <-c.stops:
		actual, _ := stop["bkptno"].(string)
		if actual != breakpointNumber {
			return nil, fmt.Errorf("expected breakpoint %s, stopped at %s",
				breakpointNumber, stopLocation(stop, actual))
		}
		return stop, nil
	case <-ctx.Done():
		return nil, ctx.Err()
	case <-time.After(c.stopTimeout):
		return nil, fmt.Errorf("target did not stop within %.1fs", c.stopTimeout.Seconds())
	}
}

func stopLocation(stop map[string]any, actual string) string {
	if actual != "" {
		return actual
	}
	frame, _ := stop["frame"].(map[string]any)
	if function, ok := frame["func"].(string); ok {
		return function
	}
	if addr, ok := frame["addr"].(string); ok {
		return addr
	}
	return "unknown"
}

// ReadU32 evaluates *(unsigned int *)&name, mirroring read_u32.
func (c *Client) ReadU32(name string) (uint32, error) {
	expression := fmt.Sprintf("*(unsigned int *)&%s", name)
	record, err := c.checkedSend(c.cmdTimeout, "data-evaluate-expression", expression)
	if err != nil {
		return 0, err
	}
	payload, _ := record["payload"].(map[string]any)
	value, ok := payload["value"].(string)
	if !ok {
		return 0, fmt.Errorf("no scalar value returned for %s: %v", name, record)
	}
	return parseU32(value)
}

// WriteU32 sets the 32-bit value at &name via a console set command,
// mirroring write_u32.
func (c *Client) WriteU32(name string, value uint32) error {
	command := fmt.Sprintf("set {unsigned int}&%s = %d", name, value)
	_, err := c.checkedSend(c.cmdTimeout, "interpreter-exec", "console", command)
	return err
}

// Close shuts gdb down. The library's Exit() sends gdb-exit and reaps the
// process; we bound it so a wedged gdb cannot hang the caller.
func (c *Client) Close() {
	if c.gdb == nil {
		return
	}
	done := make(chan struct{})
	go func() {
		_ = c.gdb.Exit()
		close(done)
	}()
	select {
	case <-done:
	case <-time.After(c.cmdTimeout):
	}
	c.gdb = nil
}

func (c *Client) drainStops() {
	for {
		select {
		case <-c.stops:
		default:
			return
		}
	}
}

// send issues an MI command with a timeout. The library's Send blocks until
// gdb replies; we run it on a goroutine and race a timer. The buffered result
// channel lets a late reply drain without leaking the goroutine.
func (c *Client) send(timeout time.Duration, operation string, arguments ...string) (map[string]any, error) {
	type reply struct {
		record map[string]any
		err    error
	}
	ch := make(chan reply, 1)
	go func() {
		record, err := c.gdb.Send(operation, arguments...)
		ch <- reply{record, err}
	}()
	select {
	case r := <-ch:
		return r.record, r.err
	case <-time.After(timeout):
		return nil, fmt.Errorf("gdb command timed out after %.1fs: -%s",
			timeout.Seconds(), operation)
	}
}

// checkedSend is send plus the class=="error" check, mirroring _write's
// default (allow_error=False) behaviour.
func (c *Client) checkedSend(timeout time.Duration, operation string, arguments ...string) (map[string]any, error) {
	record, err := c.send(timeout, operation, arguments...)
	if err != nil {
		return nil, err
	}
	if record["class"] == "error" {
		return nil, fmt.Errorf("GDB command failed: -%s: %s", operation, errorMessage(record))
	}
	return record, nil
}

func errorMessage(record map[string]any) string {
	if payload, ok := record["payload"].(map[string]any); ok {
		if message, ok := payload["msg"].(string); ok {
			return message
		}
	}
	return fmt.Sprintf("%v", record)
}

// parseU32 mirrors gdbmi.parse_u32: strip an optional (uint32_t) cast prefix,
// parse with base-0 semantics, and mask to 32 bits.
func parseU32(value string) (uint32, error) {
	value = strings.TrimSpace(value)
	if rest, ok := strings.CutPrefix(value, "(uint32_t)"); ok {
		value = strings.TrimSpace(rest)
	}
	n, err := strconv.ParseInt(value, 0, 64)
	if err != nil {
		return 0, fmt.Errorf("could not parse u32 from %q: %w", value, err)
	}
	return uint32(uint64(n) & 0xFFFFFFFF), nil
}

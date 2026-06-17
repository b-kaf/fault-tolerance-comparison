package run

import (
	"strings"
	"testing"

	"github.com/b-kaf/fault-tolerance-comparison/harness/tui/internal/config"
)

// An absurd iterations/trials count must be rejected at the validation layer
// (before the engine pre-allocates and panics), for both entry points
// (finding #6). The bound is checked before the ELF/plugin stats, so these
// pass a non-existent repo root and still see the upper-bound error.
func TestResolveE2ERejectsHugeIterations(t *testing.T) {
	_, err := ResolveE2E("/does-not-exist", config.DefaultSettings(), "tmr", "zig", "mixed", maxRunCount+1, "")
	if err == nil || !strings.Contains(err.Error(), "iterations must be <=") {
		t.Fatalf("err = %v, want an iterations upper-bound rejection", err)
	}
}

func TestResolveFuzzRejectsHugeTrials(t *testing.T) {
	_, err := ResolveFuzz("/does-not-exist", config.DefaultSettings(), "tmr", "zig", "reg-bitflip", maxRunCount+1, "0x1", "")
	if err == nil || !strings.Contains(err.Error(), "trials must be <=") {
		t.Fatalf("err = %v, want a trials upper-bound rejection", err)
	}
}

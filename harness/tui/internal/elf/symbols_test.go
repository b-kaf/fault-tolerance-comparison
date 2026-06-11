package elf

import (
	"os/exec"
	"path/filepath"
	"strconv"
	"strings"
	"testing"
)

// Parity test against llvm-nm, which is what symbols.py parsed. For every
// built fuzz ELF, the selections the runner actually consumes (trial ABI
// symbols, harness_fuzz_* data symbols, .text range) must match an
// nm-derived reference exactly. Skips when ELFs or llvm-nm are unavailable.

func TestParityWithLlvmNm(t *testing.T) {
	if _, err := exec.LookPath("llvm-nm"); err != nil {
		t.Skip("llvm-nm not on PATH")
	}
	pattern := filepath.Join("..", "..", "..", "..", "zig-out", "harness", "*-fuzz-harness-*-m4.elf")
	elfs, err := filepath.Glob(pattern)
	if err != nil {
		t.Fatal(err)
	}
	if len(elfs) == 0 {
		t.Skipf("no fuzz harness ELFs found (run `zig build fuzz-harness`); pattern: %s", pattern)
	}

	for _, path := range elfs {
		t.Run(filepath.Base(path), func(t *testing.T) {
			want := nmSymbols(t, path)
			got, err := Load(path)
			if err != nil {
				t.Fatal(err)
			}

			if err := RequireTrialABI(got); err != nil {
				t.Fatalf("Go ABI check: %v", err)
			}
			if err := RequireTrialABI(want); err != nil {
				t.Fatalf("nm ABI check: %v", err)
			}

			compareSymbols(t, "SelectedABISymbols",
				SelectedABISymbols(got), SelectedABISymbols(want))
			compareSymbols(t, "SelectedFuzzSymbols",
				SelectedFuzzSymbols(got), SelectedFuzzSymbols(want))

			gotStart, gotEnd, err := TextRange(got)
			if err != nil {
				t.Fatal(err)
			}
			wantStart, wantEnd, err := TextRange(want)
			if err != nil {
				t.Fatal(err)
			}
			if gotStart != wantStart || gotEnd != wantEnd {
				t.Errorf("TextRange: got 0x%x..0x%x, nm reference 0x%x..0x%x",
					gotStart, gotEnd, wantStart, wantEnd)
			}

			if got["harness_main"].Address != want["harness_main"].Address {
				t.Errorf("harness_main: got 0x%x, nm reference 0x%x",
					got["harness_main"].Address, want["harness_main"].Address)
			}
		})
	}
}

func compareSymbols(t *testing.T, label string, got, want []Symbol) {
	t.Helper()
	if len(got) != len(want) {
		t.Errorf("%s: got %d symbols, nm reference %d\ngot:  %v\nwant: %v",
			label, len(got), len(want), names(got), names(want))
		return
	}
	for i := range got {
		g, w := got[i], want[i]
		if g.Name != w.Name || g.Address != w.Address || g.Size != w.Size {
			t.Errorf("%s[%d]: got %s@0x%x+%d, nm reference %s@0x%x+%d",
				label, i, g.Name, g.Address, g.Size, w.Name, w.Address, w.Size)
		}
	}
}

func names(symbols []Symbol) []string {
	out := make([]string, len(symbols))
	for i, sym := range symbols {
		out[i] = sym.Name
	}
	return out
}

// nmSymbols ports load_symbols from symbols.py: parse llvm-nm output,
// keeping the first definition unless a global supersedes a local.
func nmSymbols(t *testing.T, path string) map[string]Symbol {
	t.Helper()
	out, err := exec.Command(
		"llvm-nm", "--defined-only", "--numeric-sort", "--print-size", path,
	).Output()
	if err != nil {
		t.Fatal(err)
	}

	symbols := make(map[string]Symbol)
	for line := range strings.Lines(string(out)) {
		parts := strings.Fields(line)
		if len(parts) < 4 {
			continue
		}
		address, err1 := strconv.ParseUint(parts[0], 16, 64)
		size, err2 := strconv.ParseUint(parts[1], 16, 64)
		if err1 != nil || err2 != nil {
			continue
		}
		kind, name := parts[2][0], parts[3]
		existing, exists := symbols[name]
		if !exists || (isLower(existing.Kind) && isUpper(kind)) {
			symbols[name] = Symbol{Name: name, Address: address, Size: size, Kind: kind}
		}
	}
	return symbols
}

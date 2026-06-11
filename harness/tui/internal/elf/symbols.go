// Package elf ports harness/fuzz/runner/symbols.py from llvm-nm output
// parsing to the Go stdlib debug/elf reader. Symbols keep an nm-style kind
// letter so the selection predicates stay recognizably the same.
package elf

import (
	"debug/elf"
	"fmt"
	"sort"
	"strings"
)

type Symbol struct {
	Name    string
	Address uint64
	Size    uint64
	Kind    byte // nm-style letter: T/t, D/d, B/b, R/r, A/a, W/w
}

// TrialABISymbols is the single-shot fuzz trial ABI contract.
var TrialABISymbols = []string{
	"harness_main",
	"harness_trial_seed",
	"harness_done",
	"harness_detected",
	"harness_corrected",
	"harness_safe_state",
	"harness_output",
	"harness_expected",
	"harness_error_code",
	"harness_fault_window_open",
}

// Load reads the defined symbols of an ELF, classified with nm-style kind
// letters. Duplicate names keep the first symbol seen unless a global
// (uppercase) definition supersedes a local (lowercase) one — the same
// preference rule as symbols.py.
func Load(path string) (map[string]Symbol, error) {
	file, err := elf.Open(path)
	if err != nil {
		return nil, err
	}
	defer file.Close()

	syms, err := file.Symbols()
	if err != nil {
		return nil, fmt.Errorf("%s: %w", path, err)
	}

	symbols := make(map[string]Symbol)
	for _, sym := range syms {
		kind, ok := classify(file, sym)
		if !ok {
			continue
		}
		address := sym.Value
		// ARM function symbols carry the Thumb mode flag in bit 0; llvm-nm
		// masks it, and the PCs fed to the QEMU plugin must be real
		// instruction addresses.
		if file.Machine == elf.EM_ARM && elf.ST_TYPE(sym.Info) == elf.STT_FUNC {
			address &^= 1
		}
		entry := Symbol{Name: sym.Name, Address: address, Size: sym.Size, Kind: kind}
		existing, exists := symbols[sym.Name]
		if !exists || (isLower(existing.Kind) && isUpper(kind)) {
			symbols[sym.Name] = entry
		}
	}
	return symbols, nil
}

// classify maps a defined symbol to an nm kind letter; ok=false means the
// symbol is undefined or not a kind llvm-nm would list as a code/data symbol.
func classify(file *elf.File, sym elf.Symbol) (byte, bool) {
	if sym.Name == "" {
		return 0, false
	}
	typ := elf.ST_TYPE(sym.Info)
	if typ == elf.STT_FILE || typ == elf.STT_SECTION {
		return 0, false
	}
	shndx := elf.SectionIndex(sym.Section)
	if shndx == elf.SHN_UNDEF {
		return 0, false
	}

	var letter byte
	switch {
	case shndx == elf.SHN_ABS:
		letter = 'A'
	case shndx == elf.SHN_COMMON:
		letter = 'C'
	case int(shndx) < len(file.Sections):
		section := file.Sections[shndx]
		letter = sectionLetter(section)
	default:
		return 0, false
	}

	binding := elf.ST_BIND(sym.Info)
	if binding == elf.STB_WEAK {
		letter = 'W'
	}
	if binding == elf.STB_LOCAL {
		letter = toLower(letter)
	}
	return letter, true
}

func sectionLetter(section *elf.Section) byte {
	flags := section.Flags
	switch {
	case flags&elf.SHF_EXECINSTR != 0:
		return 'T'
	case section.Type == elf.SHT_NOBITS && flags&elf.SHF_ALLOC != 0 && flags&elf.SHF_WRITE != 0:
		return 'B'
	case flags&elf.SHF_ALLOC != 0 && flags&elf.SHF_WRITE != 0:
		return 'D'
	case flags&elf.SHF_ALLOC != 0:
		return 'R'
	default:
		return 'N'
	}
}

// RequireTrialABI mirrors symbols.require_trial_abi.
func RequireTrialABI(symbols map[string]Symbol) error {
	var missing []string
	for _, name := range TrialABISymbols {
		if _, ok := symbols[name]; !ok {
			missing = append(missing, name)
		}
	}
	if len(missing) > 0 {
		return fmt.Errorf("ELF is missing required single-shot ABI symbol(s): %s",
			strings.Join(missing, ", "))
	}
	return nil
}

// SelectedABISymbols returns the trial ABI data symbols in contract order
// (everything except harness_main).
func SelectedABISymbols(symbols map[string]Symbol) []Symbol {
	selected := make([]Symbol, 0, len(TrialABISymbols)-1)
	for _, name := range TrialABISymbols {
		if name == "harness_main" {
			continue
		}
		if sym, ok := symbols[name]; ok {
			selected = append(selected, sym)
		}
	}
	return selected
}

// SelectedFuzzSymbols returns harness_fuzz_* data symbols sorted by address —
// the order llvm-nm --numeric-sort gave the Python implementation.
func SelectedFuzzSymbols(symbols map[string]Symbol) []Symbol {
	var selected []Symbol
	for _, sym := range symbols {
		if strings.HasPrefix(sym.Name, "harness_fuzz_") && isDataKind(sym.Kind) {
			selected = append(selected, sym)
		}
	}
	sort.Slice(selected, func(i, j int) bool {
		return selected[i].Address < selected[j].Address
	})
	return selected
}

// TextRange mirrors symbols.text_range: prefer the linker-script end markers,
// fall back to the highest T/t symbol end.
func TextRange(symbols map[string]Symbol) (start, end uint64, err error) {
	entry, ok := symbols["_start"]
	if !ok {
		entry, ok = symbols["Reset_Handler"]
	}
	if !ok {
		return 0, 0, fmt.Errorf("ELF is missing _start / Reset_Handler — cannot bound .text")
	}

	// __etext / _etext mark the true end of .text. __exidx_start marks the
	// start of .ARM.exidx, which immediately follows .text on ARM.
	for _, name := range []string{"__etext", "_etext", "__exidx_start"} {
		if sym, ok := symbols[name]; ok {
			return entry.Address, sym.Address, nil
		}
	}

	var maxEnd uint64
	for _, sym := range symbols {
		if (sym.Kind == 'T' || sym.Kind == 't') && sym.Address >= entry.Address {
			maxEnd = max(maxEnd, sym.Address+max(sym.Size, 2))
		}
	}
	if maxEnd == 0 {
		return 0, 0, fmt.Errorf("no .text symbols found; cannot bound .text range")
	}
	return entry.Address, maxEnd, nil
}

func isDataKind(kind byte) bool {
	return kind == 'B' || kind == 'D' || kind == 'b' || kind == 'd'
}

func isLower(b byte) bool { return b >= 'a' && b <= 'z' }
func isUpper(b byte) bool { return b >= 'A' && b <= 'Z' }

func toLower(b byte) byte {
	if isUpper(b) {
		return b + ('a' - 'A')
	}
	return b
}

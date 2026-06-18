package fuzz

import (
	"fmt"
	"os"
	"strings"

	harnesself "github.com/b-kaf/fault-tolerance-comparison/harness/tui/internal/elf"
)

// Manifest is the per-trial key=value file consumed by the QEMU plugin,
// mirroring manifest.write_manifest. Line order is part of the format.
type Manifest struct {
	Technique       string
	Implementation  string
	Campaign        string
	CampaignSeed    uint64
	TrialID         int
	TrialSeed       uint64
	FaultMode       string
	FaultDomain     string
	MaxInstructions uint64
	WindowSkipBound uint64
	RawResult       string
	Done            string
	EntryPC         uint64
	TextStart       uint64
	TextEnd         uint64
	ABISymbols      []harnesself.Symbol
	FuzzSymbols     []harnesself.Symbol
}

func WriteManifest(path string, m Manifest) error {
	lines := []string{
		"technique=" + m.Technique,
		"language=" + m.Implementation,
		"campaign=" + m.Campaign,
		fmt.Sprintf("campaign_seed=0x%x", m.CampaignSeed),
		fmt.Sprintf("trial_id=%d", m.TrialID),
		fmt.Sprintf("trial_seed=0x%x", m.TrialSeed),
		"fault_mode=" + m.FaultMode,
		"fault_domain=" + m.FaultDomain,
		fmt.Sprintf("max_instructions=%d", m.MaxInstructions),
		fmt.Sprintf("window_skip_bound=%d", m.WindowSkipBound),
		"raw_result=" + m.RawResult,
		"done=" + m.Done,
		fmt.Sprintf("entry_pc=0x%x", m.EntryPC),
		fmt.Sprintf("text_start=0x%x", m.TextStart),
		fmt.Sprintf("text_end=0x%x", m.TextEnd),
	}
	for _, symbol := range m.ABISymbols {
		lines = append(lines,
			fmt.Sprintf("sym.%s=0x%x:0x%x", symbol.Name, symbol.Address, symbol.Size))
	}
	for _, symbol := range m.FuzzSymbols {
		lines = append(lines,
			fmt.Sprintf("fuzz.%s=0x%x:0x%x", symbol.Name, symbol.Address, symbol.Size))
	}
	return os.WriteFile(path, []byte(strings.Join(lines, "\n")+"\n"), 0o644)
}

package fuzz

import (
	"fmt"
	"os"
	"strings"

	harnesself "github.com/b-kaf/fault-tolerance-comparison/harness/tui/internal/elf"
)

// Manifest is the per-trial key=value file consumed by the QEMU plugin,
// mirroring manifest.write_manifest. Line order is part of the format.
// Manifest holds the campaign-static config the plugin reads once. Per-trial
// values (trial_seed, trial_id, window_skip_bound) and the probe's fault_mode
// override are passed as plugin args instead, so a single manifest serves the
// whole campaign.
type Manifest struct {
	Technique       string
	Implementation  string
	Campaign        string
	CampaignSeed    uint64
	FaultMode       string
	FaultDomain     string
	MaxInstructions uint64
	GPRegisters     []string // register-fault allowlist (target GP registers)
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
		"fault_mode=" + m.FaultMode,
		"fault_domain=" + m.FaultDomain,
		fmt.Sprintf("max_instructions=%d", m.MaxInstructions),
		"gp_regs=" + strings.Join(m.GPRegisters, ","),
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

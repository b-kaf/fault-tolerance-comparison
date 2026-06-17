package fuzz

import (
	"slices"
	"testing"
)

// TestInsnSkipCampaign locks the insn-skip campaign's wiring: it is an
// offered choice, resolves to the insn-skip plugin mode, requires an
// injection, and is the one campaign that needs one-insn-per-tb.
func TestInsnSkipCampaign(t *testing.T) {
	if !slices.Contains(CampaignChoices, "insn-skip") {
		t.Fatalf("insn-skip missing from CampaignChoices: %v", CampaignChoices)
	}

	spec, err := CampaignByName("insn-skip")
	if err != nil {
		t.Fatalf("CampaignByName(insn-skip): %v", err)
	}
	if spec.FaultMode != "insn-skip" {
		t.Errorf("FaultMode = %q, want insn-skip", spec.FaultMode)
	}
	if spec.FaultDomain != "instruction" {
		t.Errorf("FaultDomain = %q, want instruction", spec.FaultDomain)
	}
	if !spec.RequiresInjection {
		t.Error("RequiresInjection = false, want true")
	}
	if !spec.RequiresOneInsnPerTB {
		t.Error("RequiresOneInsnPerTB = false, want true")
	}
	if spec.RequiresFuzzSymbols {
		t.Error("RequiresFuzzSymbols = true, want false (insn-skip targets the PC, not RAM symbols)")
	}
}

// TestOneInsnPerTBScopedToInsnSkip guards the gating invariant: only
// insn-skip pulls in -accel tcg,one-insn-per-tb=on, so other campaigns keep
// their previous QEMU behaviour.
func TestOneInsnPerTBScopedToInsnSkip(t *testing.T) {
	for _, name := range CampaignChoices {
		spec, err := CampaignByName(name)
		if err != nil {
			t.Fatalf("CampaignByName(%q): %v", name, err)
		}
		want := name == "insn-skip"
		if spec.RequiresOneInsnPerTB != want {
			t.Errorf("%s RequiresOneInsnPerTB = %v, want %v", name, spec.RequiresOneInsnPerTB, want)
		}
	}
}

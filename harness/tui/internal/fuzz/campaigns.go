// Package fuzz ports harness/fuzz/runner: single-shot QEMU plugin fuzz
// campaigns with per-trial manifests and the 9-way result classifier.
package fuzz

import (
	"encoding/binary"
	"fmt"
	"strings"

	"github.com/dchest/blake2b"
)

type Campaign struct {
	Name                 string
	FaultMode            string
	FaultDomain          string
	RequiresInjection    bool
	RequiresFuzzSymbols  bool
	RequiresOneInsnPerTB bool
}

var CampaignChoices = []string{"none", "ram-bitflip", "reg-bitflip", "insn-skip"}

var campaigns = map[string]Campaign{
	"none": {Name: "none", FaultMode: "none", FaultDomain: "none"},
	"ram-bitflip": {
		Name:                "ram-bitflip",
		FaultMode:           "ram-bitflip",
		FaultDomain:         "ram",
		RequiresInjection:   true,
		RequiresFuzzSymbols: true,
	},
	"reg-bitflip": {
		Name:              "reg-bitflip",
		FaultMode:         "reg-bitflip",
		FaultDomain:       "register",
		RequiresInjection: true,
	},
	"insn-skip": {
		Name:                 "insn-skip",
		FaultMode:            "insn-skip",
		FaultDomain:          "instruction",
		RequiresInjection:    true,
		RequiresOneInsnPerTB: true,
	},
}

// CampaignByName mirrors campaigns.campaign.
func CampaignByName(name string) (Campaign, error) {
	spec, ok := campaigns[name]
	if !ok {
		return Campaign{}, fmt.Errorf("unsupported campaign %q; expected one of: %s",
			name, strings.Join(CampaignChoices, ", "))
	}
	return spec, nil
}

// trialSeedFallback replaces an all-zero digest, like the Python
// `seed or 0x9E3779B97F4A7C15`.
const trialSeedFallback = 0x9E3779B97F4A7C15

// DeriveTrialSeed mirrors campaigns.derive_trial_seed: BLAKE2b with an
// 8-byte digest and the "ft-single" personalization, read little-endian.
// x/crypto/blake2b cannot express the personalization — see PLAN.md §3.
func DeriveTrialSeed(campaignSeed uint64, trialID int, technique, implementation, campaignName string) uint64 {
	payload := fmt.Sprintf("%016x:%d:%s:%s:%s",
		campaignSeed, trialID, technique, implementation, campaignName)
	hash, err := blake2b.New(&blake2b.Config{
		Size:   8,
		Person: []byte("ft-single"),
	})
	if err != nil {
		panic(err) // static config; cannot fail
	}
	hash.Write([]byte(payload))
	seed := binary.LittleEndian.Uint64(hash.Sum(nil))
	if seed == 0 {
		return trialSeedFallback
	}
	return seed
}

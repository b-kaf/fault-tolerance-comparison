package fuzz

import (
	"context"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"sort"
	"strconv"
	"strings"

	"github.com/b-kaf/fault-tolerance-comparison/harness/tui/internal/config"
	harnesself "github.com/b-kaf/fault-tolerance-comparison/harness/tui/internal/elf"
	"github.com/b-kaf/fault-tolerance-comparison/harness/tui/internal/qemu"
	"github.com/b-kaf/fault-tolerance-comparison/harness/tui/internal/result"
)

// Events carries optional engine callbacks for the TUI; all fields may be
// nil. OnTrial fires after each trial's row has been collected.
type Events struct {
	OnTrial func(trialID, total int, row map[string]string)
}

// Summary is the per-result-class histogram of a finished campaign.
type Summary struct {
	Counts map[string]int
	Trials int
}

// String matches the Python summary line: sorted name=count pairs.
func (s Summary) String() string {
	if len(s.Counts) == 0 {
		return "no trials"
	}
	return FormatCounts(s.Counts, ", ")
}

// FormatCounts renders result-class counts as sorted "name=count" pairs joined
// by sep. Empty counts yield "". Shared by the final summary and the TUI's
// live histogram so their formatting cannot drift.
func FormatCounts(counts map[string]int, sep string) string {
	if len(counts) == 0 {
		return ""
	}
	names := make([]string, 0, len(counts))
	for name := range counts {
		names = append(names, name)
	}
	sort.Strings(names)
	parts := make([]string, len(names))
	for i, name := range names {
		parts[i] = fmt.Sprintf("%s=%d", name, counts[name])
	}
	return strings.Join(parts, sep)
}

// Run mirrors main.run: load symbols, then drive one QEMU trial per seed,
// collecting the per-trial rows in memory and returning them. Persisting the
// rows to CSV is the caller's choice (the headless CLI writes them, the TUI
// exports on demand). Cancelling ctx stops between (or mid) trial; the rows
// gathered so far are returned alongside ctx.Err().
func Run(ctx context.Context, cfg config.Fuzz, warnings io.Writer, events Events) (Summary, []map[string]string, error) {
	summary := Summary{Counts: make(map[string]int)}
	var rows []map[string]string

	spec, err := CampaignByName(cfg.Campaign)
	if err != nil {
		return summary, nil, err
	}

	symbols, err := harnesself.Load(cfg.Elf)
	if err != nil {
		return summary, nil, err
	}
	if err := harnesself.RequireTrialABI(symbols); err != nil {
		return summary, nil, err
	}

	abiSymbols := harnesself.SelectedABISymbols(symbols)
	fuzzSymbols := harnesself.SelectedFuzzSymbols(symbols)
	if spec.RequiresFuzzSymbols && len(fuzzSymbols) == 0 {
		return summary, nil, fmt.Errorf("campaign %q has no harness_fuzz_* symbols for %s/%s",
			cfg.Campaign, cfg.Technique, cfg.Language)
	}

	textStart, textEnd, err := harnesself.TextRange(symbols)
	if err != nil {
		return summary, nil, err
	}
	entryPC := symbols["harness_main"].Address

	tmpDir, err := os.MkdirTemp("", "qemu-ft-fuzz-")
	if err != nil {
		return summary, nil, err
	}
	defer os.RemoveAll(tmpDir)

	// The manifest is campaign-static (symbols, text range, fault mode), so it
	// is written once; the per-trial deltas (seed, id, window bound) ride as
	// plugin args instead of a fresh file per trial.
	manifestPath := filepath.Join(tmpDir, "manifest.txt")
	if err := WriteManifest(manifestPath, Manifest{
		Technique:       cfg.Technique,
		Implementation:  cfg.Language,
		Campaign:        cfg.Campaign,
		CampaignSeed:    cfg.Seed,
		FaultMode:       spec.FaultMode,
		FaultDomain:     spec.FaultDomain,
		MaxInstructions: cfg.MaxInstructions,
		EntryPC:         entryPC,
		TextStart:       textStart,
		TextEnd:         textEnd,
		ABISymbols:      abiSymbols,
		FuzzSymbols:     fuzzSymbols,
	}); err != nil {
		return summary, nil, err
	}

	// Windowed-offset campaigns pick the Nth executed instruction in the fault
	// window from a bounded range. Measure the clean window length once (the
	// window is data-independent, so it is identical across trials) and use it
	// as the bound, so trials spread across the whole window instead of
	// colliding within the plugin's fixed fallback range.
	var windowSkipBound uint64
	if spec.UsesWindowOffset {
		windowSkipBound, err = measureWindowLength(ctx, cfg, spec, manifestPath, warnings)
		if err != nil {
			return summary, nil, err
		}
	}

	for trialID := 0; trialID < cfg.Trials; trialID++ {
		if ctx.Err() != nil {
			return summary, rows, ctx.Err()
		}
		trialSeed := DeriveTrialSeed(cfg.Seed, trialID, cfg.Technique, cfg.Language, cfg.Campaign)
		row, err := runOneTrial(ctx, cfg, spec, manifestPath, trialID, trialSeed, windowSkipBound, warnings)
		if err != nil {
			return summary, rows, err
		}
		summary.Counts[row["result_class"]]++
		summary.Trials++
		rows = append(rows, row)
		if events.OnTrial != nil {
			events.OnTrial(trialID, cfg.Trials, row)
		}
	}
	return summary, rows, nil
}

func runOneTrial(ctx context.Context, cfg config.Fuzz, spec Campaign, manifestPath string, trialID int, trialSeed, windowSkipBound uint64, warnings io.Writer) (map[string]string, error) {
	pluginArgs := []string{
		fmt.Sprintf("trial_seed=0x%x", trialSeed),
		fmt.Sprintf("trial_id=%d", trialID),
		fmt.Sprintf("window_skip_bound=%d", windowSkipBound),
	}

	process, err := RunQemuTrial(ctx, qemu.Binary, cfg.Elf, cfg.Plugin,
		manifestPath, pluginArgs, cfg.Timeout, spec.RequiresOneInsnPerTB, warnings)
	if err != nil {
		return nil, err
	}

	facts := parseStderrFacts(process.Stderr)

	resultClass := Classify(ClassificationInput{
		Facts:             facts,
		ProcessStatus:     process.ProcessStatus,
		Timeout:           process.Timeout,
		RequiresInjection: spec.RequiresInjection,
	})
	return result.FormatFuzzResultRow(
		cfg.Technique, cfg.Language,
		trialID, trialSeed,
		cfg.Campaign, cfg.Seed,
		resultClass, facts,
		process.ProcessStatus, process.Timeout, process.ElapsedMS,
	), nil
}

// measureWindowLength runs one fault-free trial (fault_mode=none) so the plugin
// counts every instruction executed while the fault window is open without
// perturbing the path. The clean length bounds the per-trial skip offset for
// windowed-offset campaigns. A zero result (window never opened, or the field
// is absent) leaves the bound unset so the plugin keeps its built-in fallback.
func measureWindowLength(ctx context.Context, cfg config.Fuzz, spec Campaign, manifestPath string, warnings io.Writer) (uint64, error) {
	// A no-fault run: the fault window still opens, so the plugin counts every
	// windowed instruction without perturbing the path. fault_mode=none
	// overrides the campaign's mode in the shared manifest.
	process, err := RunQemuTrial(ctx, qemu.Binary, cfg.Elf, cfg.Plugin,
		manifestPath, []string{"fault_mode=none"}, cfg.Timeout, spec.RequiresOneInsnPerTB, warnings)
	if err != nil {
		return 0, err
	}

	facts := parseStderrFacts(process.Stderr)
	total, err := strconv.ParseUint(facts["window_insns_total"], 10, 64)
	if err != nil {
		return 0, nil // window never opened / field absent: keep plugin default
	}
	return total, nil
}

// parseStderrFacts extracts the plugin's result record from captured QEMU
// stderr: each result line is "@@FT key=value". Non-tagged lines (QEMU's own
// output) are ignored. Later values win, so injection-time keys emitted before
// an abort are overridden by the final record when one is produced.
func parseStderrFacts(stderr string) map[string]string {
	const tag = "@@FT "
	facts := make(map[string]string)
	for line := range strings.Lines(stderr) {
		line = strings.TrimRight(line, "\r\n")
		if !strings.HasPrefix(line, tag) {
			continue
		}
		kv := line[len(tag):]
		if !strings.Contains(kv, "=") {
			continue
		}
		key, value, _ := strings.Cut(kv, "=")
		facts[strings.TrimSpace(key)] = strings.TrimSpace(value)
	}
	return facts
}

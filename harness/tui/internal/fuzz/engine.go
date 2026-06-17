package fuzz

import (
	"context"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"sort"
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

	for trialID := 0; trialID < cfg.Trials; trialID++ {
		if ctx.Err() != nil {
			return summary, rows, ctx.Err()
		}
		trialSeed := DeriveTrialSeed(cfg.Seed, trialID, cfg.Technique, cfg.Language, cfg.Campaign)
		row, err := runOneTrial(ctx, cfg, spec, trialParams{
			tmpDir:      tmpDir,
			abiSymbols:  abiSymbols,
			fuzzSymbols: fuzzSymbols,
			entryPC:     entryPC,
			textStart:   textStart,
			textEnd:     textEnd,
			trialID:     trialID,
			trialSeed:   trialSeed,
		}, warnings)
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

type trialParams struct {
	tmpDir      string
	abiSymbols  []harnesself.Symbol
	fuzzSymbols []harnesself.Symbol
	entryPC     uint64
	textStart   uint64
	textEnd     uint64
	trialID     int
	trialSeed   uint64
}

func runOneTrial(ctx context.Context, cfg config.Fuzz, spec Campaign, p trialParams, warnings io.Writer) (map[string]string, error) {
	manifestPath := filepath.Join(p.tmpDir, fmt.Sprintf("manifest-%d.txt", p.trialID))
	rawResultPath := filepath.Join(p.tmpDir, fmt.Sprintf("raw-%d.txt", p.trialID))
	donePath := filepath.Join(p.tmpDir, fmt.Sprintf("done-%d", p.trialID))

	err := WriteManifest(manifestPath, Manifest{
		Technique:       cfg.Technique,
		Implementation:  cfg.Language,
		Campaign:        cfg.Campaign,
		CampaignSeed:    cfg.Seed,
		TrialID:         p.trialID,
		TrialSeed:       p.trialSeed,
		FaultMode:       spec.FaultMode,
		FaultDomain:     spec.FaultDomain,
		MaxInstructions: cfg.MaxInstructions,
		RawResult:       rawResultPath,
		Done:            donePath,
		EntryPC:         p.entryPC,
		TextStart:       p.textStart,
		TextEnd:         p.textEnd,
		ABISymbols:      p.abiSymbols,
		FuzzSymbols:     p.fuzzSymbols,
	})
	if err != nil {
		return nil, err
	}

	process, err := RunQemuTrial(ctx, qemu.Binary, cfg.Elf, cfg.Plugin,
		manifestPath, donePath, cfg.Timeout, spec.RequiresOneInsnPerTB, warnings)
	if err != nil {
		return nil, err
	}

	facts, err := parseRawResult(rawResultPath)
	if err != nil {
		return nil, err
	}

	resultClass := Classify(ClassificationInput{
		Facts:             facts,
		ProcessStatus:     process.ProcessStatus,
		Timeout:           process.Timeout,
		RequiresInjection: spec.RequiresInjection,
	})
	return result.FormatFuzzResultRow(
		cfg.Technique, cfg.Language,
		p.trialID, p.trialSeed,
		cfg.Campaign, cfg.Seed,
		resultClass, facts,
		process.ProcessStatus, process.Timeout, process.ElapsedMS,
	), nil
}

// parseRawResult mirrors main.parse_raw_result: key=value lines, comments
// and malformed lines skipped, missing file is empty facts.
func parseRawResult(path string) (map[string]string, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		if os.IsNotExist(err) {
			return map[string]string{}, nil
		}
		return nil, err
	}
	facts := make(map[string]string)
	for line := range strings.Lines(string(data)) {
		line = strings.TrimRight(line, "\n")
		if line == "" || strings.HasPrefix(line, "#") || !strings.Contains(line, "=") {
			continue
		}
		key, value, _ := strings.Cut(line, "=")
		facts[strings.TrimSpace(key)] = strings.TrimSpace(value)
	}
	return facts, nil
}

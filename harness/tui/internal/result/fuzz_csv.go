package result

import (
	"encoding/csv"
	"fmt"
	"io"
	"os"
	"path/filepath"
)

// FuzzCSVFields is the fixed 31-column fuzz schema.
var FuzzCSVFields = []string{
	"technique",
	"implementation",
	"trial_id",
	"trial_seed",
	"campaign",
	"campaign_seed",
	"result_class",
	"output",
	"expected",
	"detected",
	"corrected",
	"safe_state",
	"error_code",
	"harness_done",
	"injected",
	"fault_mode",
	"fault_domain",
	"target_kind",
	"target_name",
	"target_addr",
	"inject_pc",
	"inject_offset",
	"bit",
	"before",
	"after",
	"process_status",
	"timeout",
	"instruction_budget_exhausted",
	"elapsed_ms",
	"instructions_executed",
	"qemu_plugin_api",
}

// FuzzCuratedColumns is FuzzCSVFields reordered so the most useful columns
// come first (PLAN §4): the TUI shows these on the first column page, the rest
// follow on later pages. Every schema column still appears across the pages.
var FuzzCuratedColumns = curatedFuzzOrder()

func curatedFuzzOrder() []string {
	curated := []string{
		"trial_id", "result_class", "technique", "implementation",
		"fault_mode", "target_kind", "target_name", "bit",
		"process_status", "timeout", "elapsed_ms",
	}
	seen := make(map[string]bool, len(curated))
	for _, c := range curated {
		seen[c] = true
	}
	ordered := append([]string{}, curated...)
	for _, field := range FuzzCSVFields {
		if !seen[field] {
			ordered = append(ordered, field)
		}
	}
	return ordered
}

// FuzzRecord projects a fuzz result row onto the given columns.
func FuzzRecord(row map[string]string, columns []string) []string {
	record := make([]string, len(columns))
	for i, column := range columns {
		record[i] = row[column]
	}
	return record
}

var fuzzFactKeyToColumn = map[string]string{
	"harness_output":     "output",
	"harness_expected":   "expected",
	"harness_detected":   "detected",
	"harness_corrected":  "corrected",
	"harness_safe_state": "safe_state",
	"harness_error_code": "error_code",
}

// FuzzWriter streams one row per trial with a flush after each, like
// open_fuzz_result_csv.
type FuzzWriter struct {
	csv *csvWriter
}

// OpenFuzzCSV opens the fuzz result CSV and writes the header. Empty path
// writes to stdout.
func OpenFuzzCSV(path string) (*FuzzWriter, error) {
	w, err := openCSV(path, FuzzCSVFields)
	if err != nil {
		return nil, err
	}
	return &FuzzWriter{csv: w}, nil
}

// WriteRow projects the row onto the fixed schema; unknown keys are dropped,
// matching DictWriter(extrasaction="ignore").
func (w *FuzzWriter) WriteRow(row map[string]string) error {
	return w.csv.WriteRow(FuzzRecord(row, FuzzCSVFields))
}

func (w *FuzzWriter) Close() error { return w.csv.Close() }

// FormatFuzzResultRow mirrors format_fuzz_result_row: fixed identity fields
// first, then facts mapped to their columns without overwriting, then ""
// defaults for every schema column.
func FormatFuzzResultRow(
	technique, implementation string,
	trialID int,
	trialSeed uint64,
	campaign string,
	campaignSeed uint64,
	resultClass string,
	facts map[string]string,
	processStatus string,
	timeout bool,
	elapsedMS int64,
) map[string]string {
	row := map[string]string{
		"technique":      technique,
		"implementation": implementation,
		"trial_id":       fmt.Sprintf("%d", trialID),
		"trial_seed":     fmt.Sprintf("0x%016x", trialSeed),
		"campaign":       campaign,
		"campaign_seed":  fmt.Sprintf("0x%016x", campaignSeed),
		"result_class":   resultClass,
		"process_status": processStatus,
		"timeout":        boolInt(timeout),
		"elapsed_ms":     fmt.Sprintf("%d", elapsedMS),
	}
	for factKey, value := range facts {
		column, ok := fuzzFactKeyToColumn[factKey]
		if !ok {
			column = factKey
		}
		if _, exists := row[column]; !exists {
			row[column] = value
		}
	}
	for _, field := range FuzzCSVFields {
		if _, exists := row[field]; !exists {
			row[field] = ""
		}
	}
	return row
}

func boolInt(b bool) string {
	if b {
		return "1"
	}
	return "0"
}

// csvWriter writes CRLF-terminated records (the Python csv module default)
// and flushes after every row so partial campaigns leave usable files.
type csvWriter struct {
	out    io.WriteCloser
	writer *csv.Writer
}

type nopWriteCloser struct{ io.Writer }

func (nopWriteCloser) Close() error { return nil }

func openCSV(path string, header []string) (*csvWriter, error) {
	var out io.WriteCloser
	if path == "" {
		out = nopWriteCloser{os.Stdout}
	} else {
		if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
			return nil, err
		}
		file, err := os.Create(path)
		if err != nil {
			return nil, err
		}
		out = file
	}

	writer := csv.NewWriter(out)
	writer.UseCRLF = true // Python csv defaults to \r\n line terminators
	w := &csvWriter{out: out, writer: writer}
	if err := w.WriteRow(header); err != nil {
		out.Close()
		return nil, err
	}
	return w, nil
}

func (w *csvWriter) WriteRow(record []string) error {
	if err := w.writer.Write(record); err != nil {
		return err
	}
	w.writer.Flush()
	return w.writer.Error()
}

func (w *csvWriter) Close() error {
	w.writer.Flush()
	if err := w.writer.Error(); err != nil {
		w.out.Close()
		return err
	}
	return w.out.Close()
}

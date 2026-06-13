package result

import (
	"fmt"
	"maps"
	"strconv"
)

// Row is one e2e iteration's raw readings, keyed like the Python row dicts.
type Row map[string]any

var e2eBaseFields = []string{
	"technique",
	"implementation",
	"campaign",
	"iteration",
	"result",
	"pass_delta",
	"failure_delta",
	"stage",
	"stage_name",
	"fault_target",
	"fault_name",
	"fault_value",
}

var e2eTechniqueFields = map[string][]string{
	"tmr": {
		"expected",
		"value",
		"status",
		"status_name",
	},
	"checkpoint": {
		"initial_value",
		"expected",
		"value",
		"restart_status",
		"restart_status_name",
		"active_check",
		"active_check_name",
		"checkpoint_check",
		"checkpoint_check_name",
		"active_value",
		"checkpoint_value",
	},
	"recovery-block": {
		"initial_value",
		"expected",
		"value",
		"recovery_status",
		"recovery_status_name",
		"checkpoint_check",
		"checkpoint_check_name",
		"primary_check",
		"primary_check_name",
		"restore_check",
		"restore_check_name",
		"alternate_check",
		"alternate_check_name",
		"active_value",
		"checkpoint_value",
	},
	"control-flow": {
		"expected",
		"value",
		"control_status",
		"control_status_name",
		"terminal_status",
		"terminal_status_name",
		"phase",
		"phase_name",
		"signature",
		"transitions",
	},
}

var e2eCounterFields = []string{
	"passes",
	"failures",
}

// WriteE2ECSV mirrors write_e2e_result_csv: derive pass/failure deltas and
// the result column from the cumulative counters, attach *_name labels, then
// write the per-technique column set. Empty path writes to stdout.
func WriteE2ECSV(path string, rows []Row) error {
	clean := cleanE2ERows(rows)
	fields := selectedE2EFields(clean)
	w, err := openCSV(path, fields)
	if err != nil {
		return err
	}
	defer w.Close()
	for _, row := range clean {
		if err := w.WriteRow(projectRow(row, fields)); err != nil {
			return err
		}
	}
	return nil
}

// E2ETable returns the same formatted data WriteE2ECSV would write, as an
// in-memory (columns, records) pair for the TUI results table. Columns and
// values match the CSV exactly so the on-screen table and the file agree.
func E2ETable(rows []Row) (columns []string, records [][]string) {
	clean := cleanE2ERows(rows)
	columns = selectedE2EFields(clean)
	records = make([][]string, len(clean))
	for i, row := range clean {
		records[i] = projectRow(row, columns)
	}
	return columns, records
}

func cleanE2ERows(rows []Row) []Row {
	clean := make([]Row, 0, len(rows))
	var previousPasses, previousFailures int64

	for _, row := range rows {
		out := make(Row, len(row)+8)
		maps.Copy(out, row)
		passes := intField(out, "passes")
		failures := intField(out, "failures")
		passDelta := max(0, passes-previousPasses)
		failureDelta := max(0, failures-previousFailures)
		previousPasses = passes
		previousFailures = failures

		out["pass_delta"] = passDelta
		out["failure_delta"] = failureDelta
		switch {
		case failureDelta > 0:
			out["result"] = "fail"
		case passDelta > 0:
			out["result"] = "pass"
		default:
			out["result"] = "unknown"
		}

		technique, _ := out["technique"].(string)
		addLabel(out, "stage", "stage_name", stageNames)
		addLabel(out, "fault_target", "fault_name", faultNames)
		addStatusLabels(out, technique)
		clean = append(clean, out)
	}
	return clean
}

func selectedE2EFields(rows []Row) []string {
	if len(rows) == 0 {
		return append(append([]string{}, e2eBaseFields...), e2eCounterFields...)
	}
	technique, _ := rows[0]["technique"].(string)
	fields := append([]string{}, e2eBaseFields...)
	fields = append(fields, e2eTechniqueFields[technique]...)
	fields = append(fields, e2eCounterFields...)

	selected := fields[:0]
	for _, field := range fields {
		for _, row := range rows {
			if _, ok := row[field]; ok {
				selected = append(selected, field)
				break
			}
		}
	}
	return selected
}

func addStatusLabels(row Row, technique string) {
	switch technique {
	case "recovery-block":
		addLabel(row, "status", "status_name", recoveryStatusNames)
	case "control-flow":
		addLabel(row, "status", "status_name", controlStatusNames)
	default: // tmr and anything else, matching the Python fallback
		addLabel(row, "status", "status_name", tmrStatusNames)
	}

	addLabel(row, "restart_status", "restart_status_name", restartStatusNames)
	addLabel(row, "recovery_status", "recovery_status_name", recoveryStatusNames)
	addLabel(row, "control_status", "control_status_name", controlStatusNames)
	addLabel(row, "terminal_status", "terminal_status_name", controlStatusNames)
	addLabel(row, "phase", "phase_name", phaseNames)
	for _, field := range []string{
		"active_check",
		"checkpoint_check",
		"primary_check",
		"restore_check",
		"alternate_check",
	} {
		addLabel(row, field, field+"_name", checkStatusNames)
	}
}

func addLabel(row Row, sourceField, labelField string, names map[int64]string) {
	value, ok := row[sourceField]
	if !ok || formatValue(value) == "" {
		return
	}
	n := intField(row, sourceField)
	if name, ok := names[n]; ok {
		row[labelField] = name
	} else {
		row[labelField] = fmt.Sprintf("unknown_%d", n)
	}
}

// intField mirrors _int_field: missing or empty is 0, strings parse with
// base-0 semantics.
func intField(row Row, field string) int64 {
	switch v := row[field].(type) {
	case nil:
		return 0
	case int:
		return int64(v)
	case int64:
		return v
	case uint32:
		return int64(v)
	case uint64:
		return int64(v)
	case string:
		if v == "" {
			return 0
		}
		n, err := strconv.ParseInt(v, 0, 64)
		if err != nil {
			panic(fmt.Sprintf("non-integer value in field %s: %q", field, v))
		}
		return n
	default:
		panic(fmt.Sprintf("unsupported value type in field %s: %T", field, v))
	}
}

func projectRow(row Row, fields []string) []string {
	record := make([]string, len(fields))
	for i, field := range fields {
		record[i] = formatValue(row[field])
	}
	return record
}

// formatValue matches Python's str() for the types rows actually hold:
// integers in decimal, strings as-is, missing values empty.
func formatValue(value any) string {
	switch v := value.(type) {
	case nil:
		return ""
	case string:
		return v
	case int:
		return strconv.Itoa(v)
	case int64:
		return strconv.FormatInt(v, 10)
	case uint32:
		return strconv.FormatUint(uint64(v), 10)
	case uint64:
		return strconv.FormatUint(v, 10)
	case bool:
		if v {
			return "1"
		}
		return "0"
	default:
		return fmt.Sprint(v)
	}
}

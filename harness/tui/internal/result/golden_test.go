package result

import (
	"bytes"
	"encoding/json"
	"os"
	"path/filepath"
	"strconv"
	"testing"
)

// The golden CSVs in testdata/ are produced by the Python implementation
// (gen_golden.py) from rows.json. These tests replay the same rows through
// the Go port and require byte-identical output.

type fuzzTrial struct {
	Technique      string            `json:"technique"`
	Implementation string            `json:"implementation"`
	TrialID        int               `json:"trial_id"`
	TrialSeed      uint64            `json:"trial_seed"`
	Campaign       string            `json:"campaign"`
	CampaignSeed   uint64            `json:"campaign_seed"`
	ResultClass    string            `json:"result_class"`
	Facts          map[string]string `json:"facts"`
	ProcessStatus  string            `json:"process_status"`
	Timeout        bool              `json:"timeout"`
	ElapsedMS      int64             `json:"elapsed_ms"`
}

func loadFixture(t *testing.T) (map[string][]Row, []fuzzTrial) {
	t.Helper()
	data, err := os.ReadFile(filepath.Join("testdata", "rows.json"))
	if err != nil {
		t.Fatal(err)
	}

	var raw map[string]json.RawMessage
	if err := json.Unmarshal(data, &raw); err != nil {
		t.Fatal(err)
	}

	e2e := make(map[string][]Row)
	for key, message := range raw {
		if key == "fuzz" {
			continue
		}
		decoder := json.NewDecoder(bytes.NewReader(message))
		decoder.UseNumber()
		var rows []map[string]any
		if err := decoder.Decode(&rows); err != nil {
			t.Fatalf("%s: %v", key, err)
		}
		converted := make([]Row, len(rows))
		for i, row := range rows {
			out := make(Row, len(row))
			for field, value := range row {
				if number, ok := value.(json.Number); ok {
					n, err := strconv.ParseInt(number.String(), 10, 64)
					if err != nil {
						t.Fatalf("%s[%d].%s: %v", key, i, field, err)
					}
					out[field] = n
				} else {
					out[field] = value
				}
			}
			converted[i] = out
		}
		e2e[key] = converted
	}

	var trials []fuzzTrial
	if err := json.Unmarshal(raw["fuzz"], &trials); err != nil {
		t.Fatal(err)
	}
	return e2e, trials
}

func compareWithGolden(t *testing.T, gotPath, goldenName string) {
	t.Helper()
	got, err := os.ReadFile(gotPath)
	if err != nil {
		t.Fatal(err)
	}
	want, err := os.ReadFile(filepath.Join("testdata", goldenName))
	if err != nil {
		t.Fatal(err)
	}
	if !bytes.Equal(got, want) {
		t.Errorf("output differs from Python golden %s\ngot:\n%s\nwant:\n%s",
			goldenName, got, want)
	}
}

func TestWriteE2ECSVMatchesPythonGolden(t *testing.T) {
	fixtures, _ := loadFixture(t)
	for key, rows := range fixtures {
		t.Run(key, func(t *testing.T) {
			path := filepath.Join(t.TempDir(), "out.csv")
			if err := WriteE2ECSV(path, rows); err != nil {
				t.Fatal(err)
			}
			compareWithGolden(t, path, key+".csv")
		})
	}
}

func TestWriteE2ECSVEmptyMatchesPythonGolden(t *testing.T) {
	path := filepath.Join(t.TempDir(), "out.csv")
	if err := WriteE2ECSV(path, nil); err != nil {
		t.Fatal(err)
	}
	compareWithGolden(t, path, "e2e_empty.csv")
}

func TestFuzzCSVMatchesPythonGolden(t *testing.T) {
	_, trials := loadFixture(t)
	path := filepath.Join(t.TempDir(), "out.csv")
	writer, err := OpenFuzzCSV(path)
	if err != nil {
		t.Fatal(err)
	}
	for _, trial := range trials {
		row := FormatFuzzResultRow(
			trial.Technique, trial.Implementation,
			trial.TrialID, trial.TrialSeed,
			trial.Campaign, trial.CampaignSeed,
			trial.ResultClass, trial.Facts,
			trial.ProcessStatus, trial.Timeout, trial.ElapsedMS,
		)
		if err := writer.WriteRow(row); err != nil {
			t.Fatal(err)
		}
	}
	if err := writer.Close(); err != nil {
		t.Fatal(err)
	}
	compareWithGolden(t, path, "fuzz.csv")
}

"""Generate golden CSVs from the Python harness_shared implementation.

Run from the repo root:
    uv run --directory harness/e2e/injector python \
        ../../tui/internal/result/testdata/gen_golden.py

The Go tests in internal/result compare their output byte-for-byte against
the files this writes. Regenerate only while the Python tree still exists
(it is deleted in phase 7).
"""

from __future__ import annotations

import json
from pathlib import Path

from harness_shared.result_format import (
    format_fuzz_result_row,
    open_fuzz_result_csv,
    write_e2e_result_csv,
)

TESTDATA = Path(__file__).resolve().parent


def main() -> None:
    rows = json.loads((TESTDATA / "rows.json").read_text(encoding="utf-8"))

    for key in ("e2e_tmr", "e2e_checkpoint", "e2e_recovery_block", "e2e_control_flow"):
        write_e2e_result_csv(TESTDATA / f"{key}.csv", rows[key])
    write_e2e_result_csv(TESTDATA / "e2e_empty.csv", [])

    with open_fuzz_result_csv(TESTDATA / "fuzz.csv") as writer:
        for trial in rows["fuzz"]:
            writer.write_row(
                format_fuzz_result_row(
                    technique=trial["technique"],
                    implementation=trial["implementation"],
                    trial_id=trial["trial_id"],
                    trial_seed=trial["trial_seed"],
                    campaign=trial["campaign"],
                    campaign_seed=trial["campaign_seed"],
                    result_class=trial["result_class"],
                    facts=trial["facts"],
                    process_status=trial["process_status"],
                    timeout=trial["timeout"],
                    elapsed_ms=trial["elapsed_ms"],
                )
            )
    print(f"golden CSVs written to {TESTDATA}")


if __name__ == "__main__":
    main()

"""CSV formatting for e2e and fuzz harness campaign results."""

from __future__ import annotations

import csv
from contextlib import contextmanager
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable, Iterator, TextIO

from harness_shared.support import _open_csv_output


_STAGE_NAMES = {
    0: "boot",
    1: "after_init",
    2: "before_read",
    3: "after_read",
    4: "after_checkpoint",
    5: "after_mutation",
    6: "before_commit",
    7: "after_commit",
    8: "before_recovery",
    9: "after_primary",
    10: "after_alternate",
    11: "after_recovery",
    12: "before_control_flow",
    13: "after_control_read",
    14: "after_control_compute",
    15: "after_control_flow",
}

_FAULT_NAMES = {
    0: "none",
    1: "copy_a",
    2: "all_distinct",
    10: "active_value",
    11: "active_length",
    12: "active_checksum",
    13: "checkpoint_value",
    14: "checkpoint_checksum",
    15: "active_value_and_checkpoint_checksum",
    20: "recovery_primary_value",
    21: "recovery_primary_checksum",
    22: "recovery_primary_value_and_alternate_checksum",
    23: "recovery_primary_value_and_checkpoint_checksum",
    30: "control_phase",
    31: "control_signature",
    32: "control_skip_compute",
    33: "control_repeat_read",
    34: "control_early_terminal",
}

_TMR_STATUS_NAMES = {
    0: "ok",
    1: "no_majority",
}

_RESTART_STATUS_NAMES = {
    0: "committed",
    1: "restored",
    2: "restore_failed",
}

_RECOVERY_STATUS_NAMES = {
    0: "primary_accepted",
    1: "alternate_accepted",
    2: "unrecoverable",
    3: "checkpoint_failed",
    4: "restore_failed",
}

_CONTROL_STATUS_NAMES = {
    0: "ok",
    1: "invalid_transition",
    2: "bad_signature",
    3: "unexpected_terminal",
}

_CHECK_STATUS_NAMES = {
    0: "ok",
    1: "below_min",
    2: "above_max",
    3: "invalid_length",
    4: "invalid_checksum",
    5: "inconsistent_fields",
    6: "invalid_tag",
}

_PHASE_NAMES = {
    0: "start",
    1: "read_input",
    2: "compute",
    3: "validate",
    4: "commit",
    5: "done",
}

_E2E_BASE_FIELDS = [
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
]

_E2E_TECHNIQUE_FIELDS = {
    "tmr": [
        "expected",
        "value",
        "status",
        "status_name",
    ],
    "checkpoint": [
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
    ],
    "recovery-block": [
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
    ],
    "control-flow": [
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
    ],
}

_E2E_COUNTER_FIELDS = [
    "passes",
    "failures",
]

_E2E_PLUGIN_FIELDS = [
    "seed",
    "fault_mode",
    "target_kind",
    "target_name",
    "inject_pc",
    "inject_offset",
    "target_addr",
    "bit",
    "before",
    "after",
    "qemu_plugin_api",
]

_FUZZ_CSV_FIELDS = [
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
]

_FUZZ_FACT_KEY_TO_COLUMN = {
    "harness_output": "output",
    "harness_expected": "expected",
    "harness_detected": "detected",
    "harness_corrected": "corrected",
    "harness_safe_state": "safe_state",
    "harness_error_code": "error_code",
}


@dataclass
class ResultCsvWriter:
    output: TextIO
    writer: csv.DictWriter

    def write_row(self, row: dict[str, object]) -> None:
        self.writer.writerow(row)
        self.output.flush()

    def write_rows(self, rows: Iterable[dict[str, object]]) -> None:
        self.writer.writerows(rows)
        self.output.flush()


@contextmanager
def _open_result_csv(
    path: Path | str | None,
    fieldnames: list[str],
) -> Iterator[ResultCsvWriter]:
    with _open_csv_output(path) as output:
        writer = csv.DictWriter(output, fieldnames=fieldnames, extrasaction="ignore")
        writer.writeheader()
        yield ResultCsvWriter(output=output, writer=writer)


def _write_result_rows(
    path: Path | str | None,
    rows: Iterable[dict[str, object]],
    fieldnames: list[str],
) -> None:
    with _open_result_csv(path, fieldnames) as writer:
        writer.write_rows(rows)


def write_e2e_result_csv(path: Path | str | None, rows: list[dict[str, object]]) -> None:
    clean_rows = _clean_e2e_result_rows(rows)
    fieldnames = _selected_e2e_fields(clean_rows)
    _write_result_rows(path, clean_rows, fieldnames)


@contextmanager
def open_fuzz_result_csv(path: Path | str | None) -> Iterator[ResultCsvWriter]:
    with _open_result_csv(path, _FUZZ_CSV_FIELDS) as writer:
        yield writer


def write_fuzz_result_csv(
    path: Path | str | None,
    rows: Iterable[dict[str, object]],
) -> None:
    _write_result_rows(path, rows, _FUZZ_CSV_FIELDS)


def rewrite_e2e_result_csv(input_path: Path, output_path: Path) -> None:
    with input_path.open(newline="", encoding="utf-8") as file:
        rows = list(csv.DictReader(file))
    write_e2e_result_csv(output_path, rows)


def format_fuzz_result_row(
    *,
    technique: str,
    implementation: str,
    trial_id: int,
    trial_seed: int,
    campaign: str,
    campaign_seed: int,
    result_class: str,
    facts: dict[str, str],
    process_status: str,
    timeout: bool,
    elapsed_ms: int,
) -> dict[str, object]:
    row: dict[str, object] = {
        "technique": technique,
        "implementation": implementation,
        "trial_id": trial_id,
        "trial_seed": f"0x{trial_seed:016x}",
        "campaign": campaign,
        "campaign_seed": f"0x{campaign_seed:016x}",
        "result_class": result_class,
        "process_status": process_status,
        "timeout": int(timeout),
        "elapsed_ms": elapsed_ms,
    }
    for fact_key, value in facts.items():
        column = _FUZZ_FACT_KEY_TO_COLUMN.get(fact_key, fact_key)
        row.setdefault(column, value)
    for field in _FUZZ_CSV_FIELDS:
        row.setdefault(field, "")
    return row


def _clean_e2e_result_rows(rows: Iterable[dict[str, object]]) -> list[dict[str, object]]:
    clean_rows: list[dict[str, object]] = []
    previous_passes = 0
    previous_failures = 0

    for row in rows:
        clean = {key: _normalize(value) for key, value in row.items()}
        passes = _int_field(clean, "passes")
        failures = _int_field(clean, "failures")
        pass_delta = max(0, passes - previous_passes)
        failure_delta = max(0, failures - previous_failures)
        previous_passes = passes
        previous_failures = failures

        clean["pass_delta"] = pass_delta
        clean["failure_delta"] = failure_delta
        if failure_delta > 0:
            clean["result"] = "fail"
        elif pass_delta > 0:
            clean["result"] = "pass"
        else:
            clean["result"] = "unknown"

        technique = clean.get("technique", "")
        _add_label(clean, "stage", "stage_name", _STAGE_NAMES)
        _add_label(clean, "fault_target", "fault_name", _FAULT_NAMES)
        _add_status_labels(clean, technique)
        clean_rows.append(clean)

    return clean_rows


def _selected_e2e_fields(rows: list[dict[str, object]]) -> list[str]:
    if not rows:
        return _E2E_BASE_FIELDS + _E2E_COUNTER_FIELDS

    technique = str(rows[0].get("technique", ""))
    fields = list(_E2E_BASE_FIELDS)
    fields.extend(_E2E_TECHNIQUE_FIELDS.get(technique, []))
    fields.extend(_E2E_COUNTER_FIELDS)

    if any(_has_value(row, "seed") or _has_value(row, "fault_mode") for row in rows):
        fields.extend(_E2E_PLUGIN_FIELDS)

    return [field for field in fields if any(field in row for row in rows)]


def _add_status_labels(row: dict[str, object], technique: object) -> None:
    technique_name = str(technique)
    if technique_name == "tmr":
        _add_label(row, "status", "status_name", _TMR_STATUS_NAMES)
    elif technique_name == "recovery-block":
        _add_label(row, "status", "status_name", _RECOVERY_STATUS_NAMES)
    elif technique_name == "control-flow":
        _add_label(row, "status", "status_name", _CONTROL_STATUS_NAMES)
    else:
        _add_label(row, "status", "status_name", _TMR_STATUS_NAMES)

    _add_label(row, "restart_status", "restart_status_name", _RESTART_STATUS_NAMES)
    _add_label(row, "recovery_status", "recovery_status_name", _RECOVERY_STATUS_NAMES)
    _add_label(row, "control_status", "control_status_name", _CONTROL_STATUS_NAMES)
    _add_label(row, "terminal_status", "terminal_status_name", _CONTROL_STATUS_NAMES)
    _add_label(row, "phase", "phase_name", _PHASE_NAMES)
    for field in (
        "active_check",
        "checkpoint_check",
        "primary_check",
        "restore_check",
        "alternate_check",
    ):
        _add_label(row, field, f"{field}_name", _CHECK_STATUS_NAMES)


def _add_label(
    row: dict[str, object],
    source_field: str,
    label_field: str,
    names: dict[int, str],
) -> None:
    if source_field not in row or _normalize(row[source_field]) == "":
        return
    value = _int_field(row, source_field)
    row[label_field] = names.get(value, f"unknown_{value}")


def _int_field(row: dict[str, object], field: str) -> int:
    value = _normalize(row.get(field, ""))
    if value == "":
        return 0
    if isinstance(value, int):
        return value
    return int(str(value), 0)


def _normalize(value: object) -> object:
    if value is None:
        return ""
    return value


def _has_value(row: dict[str, object], field: str) -> bool:
    return field in row and _normalize(row[field]) != ""

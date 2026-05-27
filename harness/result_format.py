from __future__ import annotations

import csv
import sys
from pathlib import Path
from typing import Iterable


STAGE_NAMES = {
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

FAULT_NAMES = {
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

TMR_STATUS_NAMES = {
    0: "ok",
    1: "no_majority",
}

RESTART_STATUS_NAMES = {
    0: "committed",
    1: "restored",
    2: "restore_failed",
}

RECOVERY_STATUS_NAMES = {
    0: "primary_accepted",
    1: "alternate_accepted",
    2: "unrecoverable",
    3: "checkpoint_failed",
    4: "restore_failed",
}

CONTROL_STATUS_NAMES = {
    0: "ok",
    1: "invalid_transition",
    2: "bad_signature",
    3: "unexpected_terminal",
}

CHECK_STATUS_NAMES = {
    0: "ok",
    1: "below_min",
    2: "above_max",
    3: "invalid_length",
    4: "invalid_checksum",
    5: "inconsistent_fields",
    6: "invalid_tag",
}

PHASE_NAMES = {
    0: "start",
    1: "read_input",
    2: "compute",
    3: "validate",
    4: "commit",
    5: "done",
}

BASE_FIELDS = [
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

TECHNIQUE_FIELDS = {
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

COUNTER_FIELDS = [
    "passes",
    "failures",
]

PLUGIN_FIELDS = [
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


def write_result_csv(path: Path | None, rows: list[dict[str, object]]) -> None:
    clean_rows = clean_result_rows(rows)
    fieldnames = selected_fields(clean_rows)
    output = open(path, "w", newline="", encoding="utf-8") if path else sys.stdout
    try:
        writer = csv.DictWriter(output, fieldnames=fieldnames, extrasaction="ignore")
        writer.writeheader()
        writer.writerows(clean_rows)
    finally:
        if path:
            output.close()


def rewrite_result_csv(input_path: Path, output_path: Path) -> None:
    with input_path.open(newline="", encoding="utf-8") as file:
        rows = list(csv.DictReader(file))
    write_result_csv(output_path, rows)


def clean_result_rows(rows: Iterable[dict[str, object]]) -> list[dict[str, object]]:
    clean_rows: list[dict[str, object]] = []
    previous_passes = 0
    previous_failures = 0

    for row in rows:
        clean = {key: normalize(value) for key, value in row.items()}
        passes = int_field(clean, "passes")
        failures = int_field(clean, "failures")
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
        add_label(clean, "stage", "stage_name", STAGE_NAMES)
        add_label(clean, "fault_target", "fault_name", FAULT_NAMES)
        add_status_labels(clean, technique)
        clean_rows.append(clean)

    return clean_rows


def selected_fields(rows: list[dict[str, object]]) -> list[str]:
    if not rows:
        return BASE_FIELDS + COUNTER_FIELDS

    technique = str(rows[0].get("technique", ""))
    fields = list(BASE_FIELDS)
    fields.extend(TECHNIQUE_FIELDS.get(technique, []))
    fields.extend(COUNTER_FIELDS)

    if any(has_value(row, "seed") or has_value(row, "fault_mode") for row in rows):
        fields.extend(PLUGIN_FIELDS)

    return [field for field in fields if any(field in row for row in rows)]


def add_status_labels(row: dict[str, object], technique: object) -> None:
    technique_name = str(technique)
    if technique_name == "tmr":
        add_label(row, "status", "status_name", TMR_STATUS_NAMES)
    elif technique_name == "recovery-block":
        add_label(row, "status", "status_name", RECOVERY_STATUS_NAMES)
    elif technique_name == "control-flow":
        add_label(row, "status", "status_name", CONTROL_STATUS_NAMES)
    else:
        add_label(row, "status", "status_name", TMR_STATUS_NAMES)

    add_label(row, "restart_status", "restart_status_name", RESTART_STATUS_NAMES)
    add_label(row, "recovery_status", "recovery_status_name", RECOVERY_STATUS_NAMES)
    add_label(row, "control_status", "control_status_name", CONTROL_STATUS_NAMES)
    add_label(row, "terminal_status", "terminal_status_name", CONTROL_STATUS_NAMES)
    add_label(row, "phase", "phase_name", PHASE_NAMES)
    for field in (
        "active_check",
        "checkpoint_check",
        "primary_check",
        "restore_check",
        "alternate_check",
    ):
        add_label(row, field, f"{field}_name", CHECK_STATUS_NAMES)


def add_label(
    row: dict[str, object],
    source_field: str,
    label_field: str,
    names: dict[int, str],
) -> None:
    if source_field not in row or normalize(row[source_field]) == "":
        return
    value = int_field(row, source_field)
    row[label_field] = names.get(value, f"unknown_{value}")


def int_field(row: dict[str, object], field: str) -> int:
    value = normalize(row.get(field, ""))
    if value == "":
        return 0
    if isinstance(value, int):
        return value
    return int(str(value), 0)


def normalize(value: object) -> object:
    if value is None:
        return ""
    return value


def has_value(row: dict[str, object], field: str) -> bool:
    return field in row and normalize(row[field]) != ""

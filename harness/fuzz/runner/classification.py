from __future__ import annotations

from dataclasses import dataclass
from typing import Mapping


@dataclass(frozen=True)
class ClassificationInput:
    facts: Mapping[str, object]
    process_status: str
    timeout: bool = False
    requires_injection: bool = False


def classify_trial(data: ClassificationInput) -> str:
    facts = data.facts

    if data.timeout or int_field(facts, "instruction_budget_exhausted", 0) != 0:
        return "hang"

    done = int_field(facts, "harness_done")
    if data.process_status.startswith("exit:") and done != 1:
        return "crash"

    required = (
        "harness_done",
        "harness_detected",
        "harness_corrected",
        "harness_safe_state",
        "harness_output",
        "harness_expected",
    )
    if any(field not in facts for field in required):
        return "invalid_trial"
    if done != 1:
        return "invalid_trial"

    detected = int_field(facts, "harness_detected", 0)
    corrected = int_field(facts, "harness_corrected", 0)
    safe_state = int_field(facts, "harness_safe_state", 0)
    output = int_field(facts, "harness_output", 0)
    expected = int_field(facts, "harness_expected", 0)
    injected = int_field(facts, "injected", 0)

    if corrected and not detected:
        return "invalid_trial"
    if safe_state and not detected:
        return "invalid_trial"
    if corrected and output != expected:
        return "invalid_trial"
    if data.requires_injection and not injected:
        return "invalid_trial"

    if safe_state and detected:
        return "fail_safe"
    if detected and output == expected:
        return "corrected"
    if detected:
        return "detected"
    if output != expected:
        return "sdc"
    return "passed"


def int_field(
    facts: Mapping[str, object],
    name: str,
    default: int | None = None,
) -> int | None:
    value = facts.get(name)
    if value is None or value == "":
        return default
    if isinstance(value, bool):
        return int(value)
    if isinstance(value, int):
        return value
    return int(str(value), 0)

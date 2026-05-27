from __future__ import annotations

import subprocess
from dataclasses import dataclass
from pathlib import Path


@dataclass(frozen=True)
class Symbol:
    name: str
    address: int
    size: int
    kind: str


HOOK_SYMBOLS: dict[str, tuple[str, str]] = {
    "tmr": (
        "harness_injection_point_after_init",
        "harness_injection_point_after_read",
    ),
    "checkpoint": (
        "harness_injection_point_after_mutation",
        "harness_injection_point_after_commit",
    ),
    "recovery-block": (
        "harness_injection_point_before_recovery",
        "harness_injection_point_after_recovery",
    ),
    "control-flow": (
        "harness_injection_point_before_control_flow",
        "harness_injection_point_after_control_flow",
    ),
}

TELEMETRY_SYMBOLS: tuple[str, ...] = (
    "harness_iteration",
    "harness_stage",
    "harness_fault_target",
    "harness_fault_value",
    "harness_last_expected",
    "harness_last_initial_value",
    "harness_last_value",
    "harness_last_status",
    "harness_last_restart_status",
    "harness_last_recovery_status",
    "harness_last_control_status",
    "harness_last_terminal_status",
    "harness_last_active_check",
    "harness_last_checkpoint_check",
    "harness_last_primary_check",
    "harness_last_restore_check",
    "harness_last_alternate_check",
    "harness_last_phase",
    "harness_last_signature",
    "harness_last_transitions",
    "harness_last_active_value",
    "harness_last_checkpoint_value",
    "harness_last_fault_target",
    "harness_passes",
    "harness_failures",
)

FUZZ_SYMBOLS: dict[tuple[str, str], tuple[str, ...]] = {
    ("tmr", "c"): ("harness_c_tmr_state",),
    ("checkpoint", "c"): ("harness_c_checkpoint_state",),
    ("recovery-block", "c"): ("harness_c_recovery_block_state",),
}


def load_symbols(elf: Path, llvm_nm: str) -> dict[str, Symbol]:
    command = [
        llvm_nm,
        "--defined-only",
        "--numeric-sort",
        "--print-size",
        str(elf),
    ]
    proc = subprocess.run(
        command,
        check=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
    )

    symbols: dict[str, Symbol] = {}
    for line in proc.stdout.splitlines():
        parts = line.split()
        if len(parts) < 4:
            continue
        address_text, size_text, kind, name = parts[0], parts[1], parts[2], parts[3]
        try:
            address = int(address_text, 16)
            size = int(size_text, 16)
        except ValueError:
            continue

        # Prefer global symbols when Zig also emits local namespaced aliases.
        existing = symbols.get(name)
        if existing is None or (existing.kind.islower() and kind.isupper()):
            symbols[name] = Symbol(
                name=name,
                address=address,
                size=size,
                kind=kind,
            )
    return symbols


def required_hook_symbols(technique: str) -> tuple[str, str]:
    try:
        return HOOK_SYMBOLS[technique]
    except KeyError as exc:
        raise ValueError(f"unsupported technique: {technique}") from exc


def selected_telemetry_symbols(symbols: dict[str, Symbol]) -> list[Symbol]:
    return [symbols[name] for name in TELEMETRY_SYMBOLS if name in symbols]


def selected_fuzz_symbols(
    symbols: dict[str, Symbol],
    technique: str,
    language: str,
) -> list[Symbol]:
    names = FUZZ_SYMBOLS.get((technique, language), ())
    return [symbols[name] for name in names if name in symbols]


def text_range(symbols: dict[str, Symbol]) -> tuple[int, int]:
    start = symbols.get("_start") or symbols.get("Reset_Handler")
    end = symbols.get("__exidx_start") or symbols.get("__exidx_end")
    if start is None:
        return 0, 0
    if end is None:
        text_symbols = [
            symbol
            for symbol in symbols.values()
            if symbol.kind in {"T", "t"} and symbol.address >= start.address
        ]
        if not text_symbols:
            return start.address, start.address + 0x1000
        max_end = max(symbol.address + max(symbol.size, 2) for symbol in text_symbols)
        return start.address, max_end
    return start.address, end.address


def require_symbols(symbols: dict[str, Symbol], names: tuple[str, ...]) -> None:
    missing = [name for name in names if name not in symbols]
    if missing:
        joined = ", ".join(missing)
        raise ValueError(f"ELF is missing required symbol(s): {joined}")

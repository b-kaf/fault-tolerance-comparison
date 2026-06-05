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


TRIAL_ABI_SYMBOLS: tuple[str, ...] = (
    "harness_main",
    "harness_trial_seed",
    "harness_done",
    "harness_detected",
    "harness_corrected",
    "harness_safe_state",
    "harness_output",
    "harness_expected",
    "harness_error_code",
    "harness_fault_window_open",
)


def load_symbols(elf: Path, llvm_nm: str) -> dict[str, Symbol]:
    proc = subprocess.run(
        [
            llvm_nm,
            "--defined-only",
            "--numeric-sort",
            "--print-size",
            str(elf),
        ],
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
        existing = symbols.get(name)
        if existing is None or (existing.kind.islower() and kind.isupper()):
            symbols[name] = Symbol(
                name=name, address=address, size=size, kind=kind)
    return symbols


def require_trial_abi(symbols: dict[str, Symbol]) -> None:
    missing = [name for name in TRIAL_ABI_SYMBOLS if name not in symbols]
    if missing:
        raise ValueError(
            f"ELF is missing required single-shot ABI symbol(s): {', '.join(missing)}")


def selected_abi_symbols(symbols: dict[str, Symbol]) -> list[Symbol]:
    return [symbols[name] for name in TRIAL_ABI_SYMBOLS if name != "harness_main"]


def selected_fuzz_symbols(symbols: dict[str, Symbol]) -> list[Symbol]:
    return [
        symbol
        for symbol in symbols.values()
        if symbol.name.startswith("harness_fuzz_") and symbol.kind in {"B", "D", "b", "d"}
    ]


def text_range(symbols: dict[str, Symbol]) -> tuple[int, int]:
    start = symbols.get("_start") or symbols.get("Reset_Handler")
    if start is None:
        raise ValueError(
            "ELF is missing _start / Reset_Handler — cannot bound .text")

    # __etext / _etext mark the true end of .text. __exidx_start marks the
    # start of .ARM.exidx, which immediately follows .text on ARM.
    for name in ("__etext", "_etext", "__exidx_start"):
        end = symbols.get(name)
        if end is not None:
            return start.address, end.address

    text_symbols = [
        symbol
        for symbol in symbols.values()
        if symbol.kind in {"T", "t"} and symbol.address >= start.address
    ]
    if not text_symbols:
        raise ValueError("no .text symbols found; cannot bound .text range")
    max_end = max(symbol.address + max(symbol.size, 2)
                  for symbol in text_symbols)
    return start.address, max_end

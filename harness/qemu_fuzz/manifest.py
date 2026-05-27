from __future__ import annotations

from pathlib import Path

from symbols import Symbol


def hex_value(value: int) -> str:
    return f"0x{value:x}"


def write_manifest(
    path: Path,
    *,
    technique: str,
    language: str,
    campaign: str,
    seed: int,
    iterations: int,
    csv: Path,
    done: Path,
    start_pc: int,
    end_pc: int,
    text_start: int,
    text_end: int,
    telemetry_symbols: list[Symbol],
    fuzz_symbols: list[Symbol],
) -> None:
    lines = [
        f"technique={technique}",
        f"language={language}",
        f"campaign={campaign}",
        f"seed={hex_value(seed)}",
        f"iterations={iterations}",
        f"csv={csv}",
        f"done={done}",
        f"start_pc={hex_value(start_pc)}",
        f"end_pc={hex_value(end_pc)}",
        f"text_start={hex_value(text_start)}",
        f"text_end={hex_value(text_end)}",
    ]

    for symbol in telemetry_symbols:
        lines.append(
            f"sym.{symbol.name}={hex_value(symbol.address)}:{hex_value(symbol.size)}"
        )
    for symbol in fuzz_symbols:
        lines.append(
            f"fuzz.{symbol.name}={hex_value(symbol.address)}:{hex_value(symbol.size)}"
        )

    path.write_text("\n".join(lines) + "\n", encoding="utf-8")

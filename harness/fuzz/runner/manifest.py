from __future__ import annotations

from pathlib import Path

from symbols import Symbol


def hex_value(value: int) -> str:
    return f"0x{value:x}"


def write_manifest(
    path: Path,
    *,
    technique: str,
    implementation: str,
    campaign: str,
    campaign_seed: int,
    trial_id: int,
    trial_seed: int,
    fault_mode: str,
    fault_domain: str,
    max_instructions: int,
    raw_result: Path,
    done: Path,
    entry_pc: int,
    text_start: int,
    text_end: int,
    abi_symbols: list[Symbol],
    fuzz_symbols: list[Symbol],
) -> None:
    lines = [
        f"technique={technique}",
        f"language={implementation}",
        f"campaign={campaign}",
        f"campaign_seed={hex_value(campaign_seed)}",
        f"trial_id={trial_id}",
        f"trial_seed={hex_value(trial_seed)}",
        f"fault_mode={fault_mode}",
        f"fault_domain={fault_domain}",
        f"max_instructions={max_instructions}",
        f"raw_result={raw_result}",
        f"done={done}",
        f"entry_pc={hex_value(entry_pc)}",
        f"text_start={hex_value(text_start)}",
        f"text_end={hex_value(text_end)}",
    ]

    for symbol in abi_symbols:
        lines.append(
            f"sym.{symbol.name}={hex_value(symbol.address)}:{hex_value(symbol.size)}"
        )
    for symbol in fuzz_symbols:
        lines.append(
            f"fuzz.{symbol.name}={hex_value(symbol.address)}:{hex_value(symbol.size)}"
        )

    path.write_text("\n".join(lines) + "\n", encoding="utf-8")

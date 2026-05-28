from __future__ import annotations

import argparse
import os
import sys
import tempfile
from collections import Counter
from dataclasses import dataclass
from pathlib import Path

from dotenv import load_dotenv
from harness_shared.result_format import format_fuzz_result_row, open_fuzz_result_csv
from harness_shared.support import (
    find_repo_root,
    parse_u64,
    positive_int,
)
from campaigns import CAMPAIGN_CHOICES, Campaign, campaign, derive_trial_seed
from classification import ClassificationInput, classify_trial
from manifest import write_manifest
from runner import ProcessResult, run_qemu_trial
from symbols import (
    load_symbols,
    require_trial_abi,
    selected_abi_symbols,
    selected_fuzz_symbols,
    text_range,
)


REPO_ROOT = find_repo_root(__file__)
HARNESS_OUTPUT_DIR = REPO_ROOT / "zig-out" / "harness"
QEMU = "qemu-system-arm"
LLVM_NM = "llvm-nm"

load_dotenv(override=False)


def harness_elf_path(technique: str, implementation: str) -> Path:
    return HARNESS_OUTPUT_DIR / f"{technique}-fuzz-harness-{implementation}-m4.elf"


@dataclass(frozen=True)
class RunConfig:
    technique: str
    language: str
    campaign: str
    campaign_spec: Campaign
    trials: int
    seed: int
    csv: Path | None
    timeout: float
    max_instructions: int
    plugin: Path
    elf: Path


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Run single-shot QEMU plugin fuzz campaigns.",
    )
    parser.add_argument(
        "--technique",
        choices=("tmr", "checkpoint", "recovery-block", "control-flow"),
        required=True,
    )
    parser.add_argument("--language", choices=("c", "zig"), required=True)
    parser.add_argument(
        "--campaign", choices=CAMPAIGN_CHOICES, default="reg-bitflip")
    parser.add_argument(
        "--trials",
        "--iterations",
        dest="trials",
        type=positive_int,
        default=int(os.environ.get("HARNESS_FUZZ_TRIALS", "20"), 0),
    )
    parser.add_argument(
        "--seed",
        type=parse_u64,
        default=int(os.environ.get("HARNESS_FUZZ_SEED", "0xC0DEC0DE"), 0),
    )
    parser.add_argument(
        "--csv",
        type=Path,
        help="Write campaign results to this CSV path instead of stdout.",
    )
    return parser


def resolve_config(
    parser: argparse.ArgumentParser,
    ns: argparse.Namespace,
) -> RunConfig:
    plugin_text = os.environ.get("QEMU_FT_FUZZ_PLUGIN", "")
    if not plugin_text:
        parser.error(
            "QEMU_FT_FUZZ_PLUGIN is required in the environment or .env")

    plugin = Path(plugin_text)
    if not plugin.is_file():
        parser.error(f"plugin not found: {plugin}")

    elf = harness_elf_path(ns.technique, ns.language)
    if not elf.is_file():
        parser.error(
            f"inferred ELF not found: {elf} (run `zig build fuzz-harness` first)")

    return RunConfig(
        technique=ns.technique,
        language=ns.language,
        campaign=ns.campaign,
        campaign_spec=campaign(ns.campaign),
        trials=ns.trials,
        seed=ns.seed,
        csv=ns.csv,
        timeout=float(os.environ.get("HARNESS_FUZZ_TIMEOUT", "5.0")),
        max_instructions=int(
            os.environ.get("HARNESS_FUZZ_MAX_INSTRUCTIONS", "1000000"), 0
        ),
        plugin=plugin,
        elf=elf,
    )


def run(config: RunConfig) -> int:
    symbols = load_symbols(config.elf, LLVM_NM)
    require_trial_abi(symbols)

    abi_symbols = selected_abi_symbols(symbols)
    fuzz_symbols = selected_fuzz_symbols(symbols)
    if config.campaign_spec.requires_fuzz_symbols and not fuzz_symbols:
        raise SystemExit(
            f"campaign {config.campaign!r} has no harness_fuzz_* symbols for "
            f"{config.technique}/{config.language}"
        )

    text_start, text_end = text_range(symbols)
    entry_pc = symbols["harness_main"].address
    counts: Counter[str] = Counter()

    with open_fuzz_result_csv(config.csv) as writer:
        with tempfile.TemporaryDirectory(prefix="qemu-ft-fuzz-") as tmp:
            tmp_path = Path(tmp)
            for trial_id in range(config.trials):
                trial_seed = derive_trial_seed(
                    campaign_seed=config.seed,
                    trial_id=trial_id,
                    technique=config.technique,
                    implementation=config.language,
                    campaign_name=config.campaign,
                )
                row = run_one_trial(
                    config=config,
                    tmp_path=tmp_path,
                    abi_symbols=abi_symbols,
                    fuzz_symbols=fuzz_symbols,
                    entry_pc=entry_pc,
                    text_start=text_start,
                    text_end=text_end,
                    trial_id=trial_id,
                    trial_seed=trial_seed,
                )
                counts[row["result_class"]] += 1
                writer.write_row(row)

    summary = ", ".join(f"{name}={count}" for name,
                        count in sorted(counts.items()))
    summary = summary or "no trials"
    if config.csv is None:
        print(f"summary: {summary}", file=sys.stderr)
    else:
        print(f"wrote {config.csv} ({summary})")
    return 0


def run_one_trial(
    *,
    config: RunConfig,
    tmp_path: Path,
    abi_symbols: list,
    fuzz_symbols: list,
    entry_pc: int,
    text_start: int,
    text_end: int,
    trial_id: int,
    trial_seed: int,
) -> dict[str, object]:
    manifest_path = tmp_path / f"manifest-{trial_id}.txt"
    raw_result_path = tmp_path / f"raw-{trial_id}.txt"
    done_path = tmp_path / f"done-{trial_id}"

    write_manifest(
        manifest_path,
        technique=config.technique,
        implementation=config.language,
        campaign=config.campaign,
        campaign_seed=config.seed,
        trial_id=trial_id,
        trial_seed=trial_seed,
        fault_mode=config.campaign_spec.fault_mode,
        fault_domain=config.campaign_spec.fault_domain,
        max_instructions=config.max_instructions,
        raw_result=raw_result_path.resolve(),
        done=done_path.resolve(),
        entry_pc=entry_pc,
        text_start=text_start,
        text_end=text_end,
        abi_symbols=abi_symbols,
        fuzz_symbols=fuzz_symbols,
    )

    process = run_qemu_trial(
        qemu=QEMU,
        elf=config.elf,
        plugin=config.plugin,
        manifest=manifest_path,
        done=done_path,
        timeout=config.timeout,
    )
    facts = parse_raw_result(raw_result_path)
    return build_csv_row(config, trial_id, trial_seed, facts, process)


def parse_raw_result(path: Path) -> dict[str, str]:
    if not path.exists():
        return {}
    facts: dict[str, str] = {}
    for line in path.read_text(encoding="utf-8").splitlines():
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        facts[key.strip()] = value.strip()
    return facts


def build_csv_row(
    config: RunConfig,
    trial_id: int,
    trial_seed: int,
    facts: dict[str, str],
    process: ProcessResult,
) -> dict[str, object]:
    result_class = classify_trial(
        ClassificationInput(
            facts=facts,
            process_status=process.process_status,
            timeout=process.timeout,
            requires_injection=config.campaign_spec.requires_injection,
        )
    )
    return format_fuzz_result_row(
        technique=config.technique,
        implementation=config.language,
        trial_id=trial_id,
        trial_seed=trial_seed,
        campaign=config.campaign,
        campaign_seed=config.seed,
        result_class=result_class,
        facts=facts,
        process_status=process.process_status,
        timeout=process.timeout,
        elapsed_ms=process.elapsed_ms,
    )


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    ns = parser.parse_args(argv)
    config = resolve_config(parser, ns)
    return run(config)


if __name__ == "__main__":
    raise SystemExit(main())

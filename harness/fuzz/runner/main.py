from __future__ import annotations

import argparse
import csv
import os
import tempfile
from collections import Counter
from dataclasses import dataclass
from pathlib import Path

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


def find_repo_root() -> Path:
    here = Path(__file__).resolve()
    for parent in (here, *here.parents):
        if (parent / ".git").exists():
            return parent
    raise RuntimeError(f"could not find repo root (no .git ancestor) from {here}")


REPO_ROOT = find_repo_root()
HARNESS_OUTPUT_DIR = REPO_ROOT / "zig-out" / "harness"
DEFAULT_RESULTS_DIR = REPO_ROOT / "results" / "qemu-ft-fuzz"

CSV_FIELDS = [
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

FACT_KEY_TO_COLUMN = {
    "harness_output": "output",
    "harness_expected": "expected",
    "harness_detected": "detected",
    "harness_corrected": "corrected",
    "harness_safe_state": "safe_state",
    "harness_error_code": "error_code",
}


def harness_elf_path(technique: str, implementation: str) -> Path:
    return HARNESS_OUTPUT_DIR / f"{technique}-fuzz-harness-{implementation}-m4.elf"


def default_csv_path(
    technique: str,
    implementation: str,
    campaign_name: str,
    campaign_seed: int,
) -> Path:
    return DEFAULT_RESULTS_DIR / (
        f"{technique}-{implementation}-{campaign_name}-{campaign_seed:016x}.csv"
    )


def parse_u64(value: str) -> int:
    parsed = int(value, 0)
    if parsed < 0 or parsed > 0xFFFFFFFFFFFFFFFF:
        raise argparse.ArgumentTypeError("value must fit in u64")
    return parsed


@dataclass(frozen=True)
class RunConfig:
    technique: str
    language: str
    campaign: str
    campaign_spec: Campaign
    trials: int
    seed: int
    csv: Path
    timeout: float
    max_instructions: int
    qemu: str
    llvm_nm: str
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
    parser.add_argument("--campaign", choices=CAMPAIGN_CHOICES, default="reg-bitflip-window")
    parser.add_argument("--trials", "--iterations", dest="trials", type=int, default=20)
    parser.add_argument("--seed", type=parse_u64, default=0xC0DEC0DE)
    parser.add_argument("--csv", type=Path)
    parser.add_argument("--timeout", type=float, default=5.0)
    parser.add_argument("--max-instructions", type=int, default=1_000_000)
    parser.add_argument("--qemu", default="qemu-system-arm")
    parser.add_argument("--llvm-nm", default="llvm-nm")
    parser.add_argument(
        "--plugin",
        type=Path,
        default=os.environ.get("QEMU_FT_FUZZ_PLUGIN"),
        help="Path to qemu-ft-fuzz.so. Defaults to QEMU_FT_FUZZ_PLUGIN.",
    )
    return parser


def resolve_config(parser: argparse.ArgumentParser, ns: argparse.Namespace) -> RunConfig:
    if ns.trials <= 0:
        parser.error("--trials must be positive")
    if ns.max_instructions <= 0:
        parser.error("--max-instructions must be positive")
    if ns.plugin is None:
        parser.error("--plugin is required unless QEMU_FT_FUZZ_PLUGIN is set")

    plugin = Path(ns.plugin)
    if not plugin.is_file():
        parser.error(f"plugin not found: {plugin}")

    elf = harness_elf_path(ns.technique, ns.language)
    if not elf.is_file():
        parser.error(f"inferred ELF not found: {elf} (run `zig build fuzz-harness` first)")

    csv_path = ns.csv or default_csv_path(ns.technique, ns.language, ns.campaign, ns.seed)

    return RunConfig(
        technique=ns.technique,
        language=ns.language,
        campaign=ns.campaign,
        campaign_spec=campaign(ns.campaign),
        trials=ns.trials,
        seed=ns.seed,
        csv=csv_path,
        timeout=ns.timeout,
        max_instructions=ns.max_instructions,
        qemu=ns.qemu,
        llvm_nm=ns.llvm_nm,
        plugin=plugin,
        elf=elf,
    )


def run(config: RunConfig) -> int:
    symbols = load_symbols(config.elf, config.llvm_nm)
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
    config.csv.parent.mkdir(parents=True, exist_ok=True)
    counts: Counter[str] = Counter()

    with config.csv.open("w", newline="", encoding="utf-8") as file:
        writer = csv.DictWriter(file, fieldnames=CSV_FIELDS, extrasaction="ignore")
        writer.writeheader()

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
                writer.writerow(row)
                file.flush()

    summary = ", ".join(f"{name}={count}" for name, count in sorted(counts.items()))
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
        qemu=config.qemu,
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
    row: dict[str, object] = {
        "technique": config.technique,
        "implementation": config.language,
        "trial_id": trial_id,
        "trial_seed": f"0x{trial_seed:016x}",
        "campaign": config.campaign,
        "campaign_seed": f"0x{config.seed:016x}",
        "result_class": result_class,
        "process_status": process.process_status,
        "timeout": int(process.timeout),
        "elapsed_ms": process.elapsed_ms,
    }
    for fact_key, value in facts.items():
        column = FACT_KEY_TO_COLUMN.get(fact_key, fact_key)
        row.setdefault(column, value)
    for field in CSV_FIELDS:
        row.setdefault(field, "")
    return row


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    ns = parser.parse_args(argv)
    config = resolve_config(parser, ns)
    return run(config)


if __name__ == "__main__":
    raise SystemExit(main())

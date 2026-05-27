from __future__ import annotations

import argparse
import csv
import os
import tempfile
from collections import Counter
from pathlib import Path

from campaigns import CAMPAIGN_CHOICES, campaign, derive_trial_seed
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


REPO_ROOT = Path(__file__).resolve().parents[3]
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


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
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
    args = parser.parse_args(argv)

    if args.trials <= 0:
        parser.error("--trials must be positive")
    if args.max_instructions <= 0:
        parser.error("--max-instructions must be positive")
    if args.plugin is None:
        parser.error("--plugin is required unless QEMU_FT_FUZZ_PLUGIN is set")

    args.plugin = Path(args.plugin)
    args.campaign_spec = campaign(args.campaign)
    args.elf = harness_elf_path(args.technique, args.language)
    if not args.elf.is_file():
        parser.error(f"inferred ELF not found: {args.elf} (run `zig build fuzz-harness` first)")
    if not args.plugin.is_file():
        parser.error(f"plugin not found: {args.plugin}")
    if args.csv is None:
        args.csv = default_csv_path(args.technique, args.language, args.campaign, args.seed)
    return args


def run(args: argparse.Namespace) -> int:
    symbols = load_symbols(args.elf, args.llvm_nm)
    require_trial_abi(symbols)

    abi_symbols = selected_abi_symbols(symbols)
    fuzz_symbols = selected_fuzz_symbols(symbols)
    if args.campaign_spec.requires_fuzz_symbols and not fuzz_symbols:
        raise SystemExit(
            f"campaign {args.campaign!r} has no harness_fuzz_* symbols for "
            f"{args.technique}/{args.language}"
        )

    text_start, text_end = text_range(symbols)
    entry_pc = symbols["harness_main"].address
    args.csv.parent.mkdir(parents=True, exist_ok=True)
    counts: Counter[str] = Counter()

    with args.csv.open("w", newline="", encoding="utf-8") as file:
        writer = csv.DictWriter(file, fieldnames=CSV_FIELDS, extrasaction="ignore")
        writer.writeheader()

        with tempfile.TemporaryDirectory(prefix="qemu-ft-fuzz-") as tmp:
            tmp_path = Path(tmp)
            for trial_id in range(args.trials):
                trial_seed = derive_trial_seed(
                    campaign_seed=args.seed,
                    trial_id=trial_id,
                    technique=args.technique,
                    implementation=args.language,
                    campaign_name=args.campaign,
                )
                row = run_one_trial(
                    args=args,
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
    print(f"wrote {args.csv} ({summary})")
    return 0


def run_one_trial(
    *,
    args: argparse.Namespace,
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
    raw_result_path.unlink(missing_ok=True)
    done_path.unlink(missing_ok=True)

    write_manifest(
        manifest_path,
        technique=args.technique,
        implementation=args.language,
        campaign=args.campaign,
        campaign_seed=args.seed,
        trial_id=trial_id,
        trial_seed=trial_seed,
        fault_mode=args.campaign_spec.fault_mode,
        fault_domain=args.campaign_spec.fault_domain,
        max_instructions=args.max_instructions,
        raw_result=raw_result_path.resolve(),
        done=done_path.resolve(),
        entry_pc=entry_pc,
        text_start=text_start,
        text_end=text_end,
        abi_symbols=abi_symbols,
        fuzz_symbols=fuzz_symbols,
    )

    process = run_qemu_trial(
        qemu=args.qemu,
        elf=args.elf,
        plugin=args.plugin,
        manifest=manifest_path,
        done=done_path,
        timeout=args.timeout,
    )
    facts = parse_raw_result(raw_result_path)
    return build_csv_row(args, trial_id, trial_seed, facts, process)


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
    args: argparse.Namespace,
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
            requires_injection=args.campaign_spec.requires_injection,
        )
    )
    row: dict[str, object] = {
        "technique": args.technique,
        "implementation": args.language,
        "trial_id": trial_id,
        "trial_seed": f"0x{trial_seed:016x}",
        "campaign": args.campaign,
        "campaign_seed": f"0x{args.seed:016x}",
        "result_class": result_class,
        "process_status": process.process_status,
        "timeout": int(process.timeout),
        "elapsed_ms": process.elapsed_ms,
    }

    aliases = {
        "output": "harness_output",
        "expected": "harness_expected",
        "detected": "harness_detected",
        "corrected": "harness_corrected",
        "safe_state": "harness_safe_state",
        "error_code": "harness_error_code",
    }
    for output_field, fact_field in aliases.items():
        row[output_field] = facts.get(fact_field, "")
    for field in CSV_FIELDS:
        row.setdefault(field, facts.get(field, ""))
    return row


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv)
    return run(args)


if __name__ == "__main__":
    raise SystemExit(main())

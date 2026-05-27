from __future__ import annotations

import argparse
import csv
import os
import sys
import tempfile
from pathlib import Path

from campaigns import CAMPAIGN_CHOICES, campaign
from manifest import write_manifest
from runner import run_qemu_until_done
from symbols import (
    load_symbols,
    required_hook_symbols,
    require_symbols,
    selected_fuzz_symbols,
    selected_telemetry_symbols,
    text_range,
)


REPO_ROOT = Path(__file__).resolve().parents[2]
HARNESS_DIR = REPO_ROOT / "harness"
HARNESS_OUTPUT_DIR = REPO_ROOT / "zig-out" / "harness"
DEFAULT_RESULTS_DIR = REPO_ROOT / "results" / "qemu-ft-fuzz"
sys.path.insert(0, str(HARNESS_DIR))

from result_format import rewrite_result_csv


def harness_elf_path(technique: str, language: str) -> Path:
    return HARNESS_OUTPUT_DIR / f"{technique}-harness-{language}-m4.elf"


def default_csv_path(technique: str, language: str, campaign_name: str, seed: int) -> Path:
    return DEFAULT_RESULTS_DIR / f"{technique}-{language}-{campaign_name}-{seed:016x}.csv"


def parse_seed(value: str) -> int:
    parsed = int(value, 0)
    if parsed < 0 or parsed > 0xFFFFFFFFFFFFFFFF:
        raise argparse.ArgumentTypeError("seed must fit in u64")
    return parsed


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Run QEMU TCG plugin fuzz campaigns against harness firmware.",
    )
    parser.add_argument(
        "--technique",
        choices=("tmr", "checkpoint", "recovery-block", "control-flow"),
        required=True,
    )
    parser.add_argument("--language", choices=("c", "zig"), required=True)
    parser.add_argument("--campaign", choices=CAMPAIGN_CHOICES, default="reg-bitflip-window")
    parser.add_argument("--iterations", type=int, default=20)
    parser.add_argument("--seed", type=parse_seed, default=0xC0DEC0DE)
    parser.add_argument("--csv", type=Path)
    parser.add_argument("--manifest", type=Path)
    parser.add_argument("--done-file", type=Path)
    parser.add_argument("--timeout", type=float, default=20.0)
    parser.add_argument("--qemu", default="qemu-system-arm")
    parser.add_argument("--llvm-nm", default="llvm-nm")
    parser.add_argument(
        "--plugin",
        type=Path,
        default=os.environ.get("QEMU_FT_FUZZ_PLUGIN"),
        help="Path to qemu-ft-fuzz.so. Defaults to QEMU_FT_FUZZ_PLUGIN.",
    )
    parser.add_argument(
        "--fail-on-harness-failures",
        action="store_true",
        help="Return nonzero if the last CSV row reports harness_failures > 0.",
    )
    args = parser.parse_args(argv)

    if args.iterations <= 0:
        parser.error("--iterations must be positive")
    if args.plugin is None:
        parser.error("--plugin is required unless QEMU_FT_FUZZ_PLUGIN is set")

    args.plugin = Path(args.plugin)
    args.campaign_spec = campaign(args.campaign)
    args.elf = harness_elf_path(args.technique, args.language)
    if not args.elf.is_file():
        parser.error(f"inferred ELF not found: {args.elf} (run `zig build harness` first)")
    if not args.plugin.is_file():
        parser.error(f"plugin not found: {args.plugin}")
    if args.csv is None:
        args.csv = default_csv_path(args.technique, args.language, args.campaign, args.seed)
    return args


def run(args: argparse.Namespace) -> int:
    symbols = load_symbols(args.elf, args.llvm_nm)
    start_hook, end_hook = required_hook_symbols(args.technique)
    require_symbols(symbols, (start_hook, end_hook))

    telemetry = selected_telemetry_symbols(symbols)
    fuzz_symbols = selected_fuzz_symbols(symbols, args.technique, args.language)
    if args.campaign_spec.requires_fuzz_symbols and not fuzz_symbols:
        raise SystemExit(
            f"campaign {args.campaign!r} has no allowlisted RAM symbols for "
            f"{args.technique}/{args.language}"
        )

    args.csv.parent.mkdir(parents=True, exist_ok=True)
    text_start, text_end = text_range(symbols)

    with tempfile.TemporaryDirectory(prefix="qemu-ft-fuzz-") as tmp:
        tmp_path = Path(tmp)
        manifest_path = args.manifest or (tmp_path / "manifest.txt")
        done_path = args.done_file or (tmp_path / "done")
        raw_csv_path = tmp_path / "raw.csv"
        if done_path.exists():
            done_path.unlink()
        if manifest_path.parent:
            manifest_path.parent.mkdir(parents=True, exist_ok=True)
        if done_path.parent:
            done_path.parent.mkdir(parents=True, exist_ok=True)

        write_manifest(
            manifest_path,
            technique=args.technique,
            language=args.language,
            campaign=args.campaign,
            seed=args.seed,
            iterations=args.iterations,
            csv=raw_csv_path.resolve(),
            done=done_path.resolve(),
            start_pc=symbols[start_hook].address,
            end_pc=symbols[end_hook].address,
            text_start=text_start,
            text_end=text_end,
            telemetry_symbols=telemetry,
            fuzz_symbols=fuzz_symbols,
        )

        run_qemu_until_done(
            qemu=args.qemu,
            elf=args.elf,
            plugin=args.plugin,
            manifest=manifest_path,
            done=done_path,
            timeout=args.timeout,
        )
        rewrite_result_csv(raw_csv_path, args.csv)

    failures = last_failures(args.csv)
    print(f"wrote {args.csv} (last failures={failures})")
    if args.fail_on_harness_failures and failures != 0:
        return 1
    return 0


def last_failures(csv_path: Path) -> int:
    with csv_path.open(newline="", encoding="utf-8") as file:
        reader = csv.DictReader(file)
        last: dict[str, str] | None = None
        for row in reader:
            last = row
    if last is None:
        return 1
    return int(last.get("failures") or "0")


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv)
    return run(args)


if __name__ == "__main__":
    raise SystemExit(main())

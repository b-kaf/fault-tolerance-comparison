"""Shared helpers for the harness Python entry points."""

from __future__ import annotations

import argparse
import subprocess
import sys
from contextlib import contextmanager
from pathlib import Path
from typing import Any, Iterator, TextIO


_QEMU_MACHINE = "mps2-an386"
_QEMU_CPU = "cortex-m4"


def find_repo_root(start: Path | str) -> Path:
    path = Path(start).resolve()
    for parent in (path, *path.parents):
        if (parent / ".git").exists():
            return parent
    raise RuntimeError(f"could not find repo root (no .git ancestor) from {path}")


def qemu_mps2_an386_command(qemu: str, elf: Path) -> list[str]:
    return [
        qemu,
        "-M",
        _QEMU_MACHINE,
        "-cpu",
        _QEMU_CPU,
        "-kernel",
        str(elf),
        "-nographic",
        "-monitor",
        "none",
        "-serial",
        "none",
    ]


def terminate_process(proc: subprocess.Popen[Any], *, timeout: float = 2.0) -> None:
    if proc.poll() is not None:
        return
    proc.terminate()
    try:
        proc.wait(timeout=timeout)
    except subprocess.TimeoutExpired:
        proc.kill()
        proc.wait(timeout=timeout)


def positive_int(value: str) -> int:
    parsed = int(value, 0)
    if parsed <= 0:
        raise argparse.ArgumentTypeError("value must be positive")
    return parsed


def parse_u64(value: str) -> int:
    parsed = int(value, 0)
    if parsed < 0 or parsed > 0xFFFFFFFFFFFFFFFF:
        raise argparse.ArgumentTypeError("value must fit in u64")
    return parsed


@contextmanager
def _open_csv_output(path: Path | str | None) -> Iterator[TextIO]:
    if path is None:
        yield sys.stdout
        return

    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="", encoding="utf-8") as file:
        yield file

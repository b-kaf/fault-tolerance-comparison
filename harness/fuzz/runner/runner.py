from __future__ import annotations

import subprocess
import sys
import time
from dataclasses import dataclass
from pathlib import Path

from harness_shared.support import qemu_mps2_an386_command, terminate_process


@dataclass(frozen=True)
class ProcessResult:
    process_status: str
    timeout: bool
    elapsed_ms: int


def qemu_command(
    *,
    qemu: str,
    elf: Path,
    plugin: Path,
    manifest: Path,
) -> list[str]:
    return qemu_mps2_an386_command(qemu, elf) + [
        "-plugin",
        f"file={plugin},manifest={manifest}",
    ]


def run_qemu_trial(
    *,
    qemu: str,
    elf: Path,
    plugin: Path,
    manifest: Path,
    done: Path,
    timeout: float,
) -> ProcessResult:
    command = qemu_command(qemu=qemu, elf=elf, plugin=plugin, manifest=manifest)
    start = time.monotonic()
    proc = subprocess.Popen(
        command,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.PIPE,
        text=True,
    )

    deadline = start + timeout
    try:
        while time.monotonic() < deadline:
            if done.exists():
                terminate_process(proc)
                return ProcessResult(
                    process_status="completed",
                    timeout=False,
                    elapsed_ms=elapsed_since_ms(start),
                )
            status = proc.poll()
            if status is not None:
                warn_on_stderr(proc, f"qemu exited with status {status}")
                return ProcessResult(
                    process_status=f"exit:{status}",
                    timeout=False,
                    elapsed_ms=elapsed_since_ms(start),
                )
            time.sleep(0.02)

        terminate_process(proc)
        warn_on_stderr(proc, "qemu timed out")
        return ProcessResult(
            process_status="timeout",
            timeout=True,
            elapsed_ms=elapsed_since_ms(start),
        )
    finally:
        if proc.poll() is None:
            terminate_process(proc)


def warn_on_stderr(proc: subprocess.Popen[str], reason: str) -> None:
    if proc.stderr is None:
        return
    try:
        stderr = proc.stderr.read()
    except ValueError:
        return
    if stderr.strip():
        print(f"warning: {reason}; qemu stderr:\n{stderr.rstrip()}", file=sys.stderr)


def elapsed_since_ms(start: float) -> int:
    return int((time.monotonic() - start) * 1000)

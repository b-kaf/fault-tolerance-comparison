from __future__ import annotations

import subprocess
import time
from dataclasses import dataclass
from pathlib import Path


@dataclass(frozen=True)
class ProcessResult:
    process_status: str
    timeout: bool
    elapsed_ms: int
    stderr: str = ""


def qemu_command(
    *,
    qemu: str,
    elf: Path,
    plugin: Path,
    manifest: Path,
) -> list[str]:
    return [
        qemu,
        "-M",
        "mps2-an386",
        "-cpu",
        "cortex-m4",
        "-kernel",
        str(elf),
        "-nographic",
        "-monitor",
        "none",
        "-serial",
        "none",
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
                terminate_qemu(proc)
                return ProcessResult(
                    process_status="completed",
                    timeout=False,
                    elapsed_ms=elapsed_since_ms(start),
                )
            status = proc.poll()
            if status is not None:
                stderr = proc.stderr.read() if proc.stderr else ""
                return ProcessResult(
                    process_status=f"exit:{status}",
                    timeout=False,
                    elapsed_ms=elapsed_since_ms(start),
                    stderr=stderr,
                )
            time.sleep(0.02)

        terminate_qemu(proc)
        return ProcessResult(
            process_status="timeout",
            timeout=True,
            elapsed_ms=elapsed_since_ms(start),
        )
    finally:
        if proc.poll() is None:
            terminate_qemu(proc)


def terminate_qemu(proc: subprocess.Popen[str]) -> None:
    proc.terminate()
    try:
        proc.wait(timeout=2)
    except subprocess.TimeoutExpired:
        proc.kill()
        proc.wait(timeout=2)


def elapsed_since_ms(start: float) -> int:
    return int((time.monotonic() - start) * 1000)

from __future__ import annotations

import subprocess
import time
from pathlib import Path


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


def run_qemu_until_done(
    *,
    qemu: str,
    elf: Path,
    plugin: Path,
    manifest: Path,
    done: Path,
    timeout: float,
) -> None:
    command = qemu_command(qemu=qemu, elf=elf, plugin=plugin, manifest=manifest)
    proc = subprocess.Popen(
        command,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.PIPE,
        text=True,
    )

    deadline = time.monotonic() + timeout
    try:
        while time.monotonic() < deadline:
            if done.exists():
                terminate_qemu(proc)
                return
            status = proc.poll()
            if status is not None:
                stderr = proc.stderr.read() if proc.stderr else ""
                raise RuntimeError(
                    f"QEMU exited before campaign completed with status {status}\n{stderr}"
                )
            time.sleep(0.05)

        raise TimeoutError(
            f"QEMU plugin campaign did not finish within {timeout:.1f}s"
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

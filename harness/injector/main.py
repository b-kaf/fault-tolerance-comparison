import argparse
import csv
import subprocess
import sys
import time
from pathlib import Path

from injector.gdbmi import GdbMi


FAULT_NONE = 0
FAULT_COPY_A = 1
FAULT_ALL_DISTINCT = 2


def qemu_command(args: argparse.Namespace) -> list[str]:
    return [
        args.qemu,
        "-M",
        "mps2-an386",
        "-cpu",
        "cortex-m4",
        "-kernel",
        str(args.elf),
        "-nographic",
        "-monitor",
        "none",
        "-serial",
        "none",
        "-S",
        "-gdb",
        f"tcp::{args.port}",
    ]


def start_qemu(args: argparse.Namespace) -> subprocess.Popen[bytes]:
    proc = subprocess.Popen(
        qemu_command(args),
        stdout=subprocess.DEVNULL,
        stderr=subprocess.PIPE,
    )
    time.sleep(args.qemu_startup_delay)
    if proc.poll() is not None:
        stderr = proc.stderr.read().decode(
            "utf-8", errors="replace") if proc.stderr else ""
        raise SystemExit(
            f"QEMU exited early with status {proc.returncode}\n{stderr}")
    return proc


def choose_fault(campaign: str, iteration: int, expected: int) -> tuple[int, int]:
    if campaign == "none":
        return FAULT_NONE, 0
    if campaign == "single-a":
        return FAULT_COPY_A, expected ^ 0xFFFFFFFF
    if campaign == "all-distinct":
        return FAULT_ALL_DISTINCT, expected ^ 0x13579BDF

    schedule = (
        (FAULT_NONE, 0),
        (FAULT_COPY_A, expected ^ 0xFFFFFFFF),
        (FAULT_ALL_DISTINCT, expected ^ 0x13579BDF),
    )
    return schedule[(iteration - 1) % len(schedule)]


def run_campaign(args: argparse.Namespace) -> int:
    qemu = start_qemu(args) if args.launch_qemu else None
    rows = []

    try:
        gdb = GdbMi(args)
        try:
            breakpoints = gdb.install_breakpoints()

            for _ in range(args.iterations):
                gdb.continue_until_breakpoint(breakpoints.after_init)

                iteration = gdb.read_u32("harness_iteration")
                expected = gdb.read_u32("harness_last_expected")
                fault_target, fault_value = choose_fault(
                    args.campaign, iteration, expected)
                gdb.write_u32("harness_fault_value", fault_value)
                gdb.write_u32("harness_fault_target", fault_target)

                gdb.continue_until_breakpoint(breakpoints.after_read)

                row = {
                    "iteration": iteration,
                    "stage": gdb.read_u32("harness_stage"),
                    "fault_target": gdb.read_u32("harness_last_fault_target"),
                    "fault_value": fault_value & 0xFFFFFFFF,
                    "expected": expected,
                    "status": gdb.read_u32("harness_last_status"),
                    "value": gdb.read_u32("harness_last_value"),
                    "passes": gdb.read_u32("harness_passes"),
                    "failures": gdb.read_u32("harness_failures"),
                }
                rows.append(row)
        finally:
            gdb.close()
    finally:
        if qemu is not None:
            qemu.terminate()
            try:
                qemu.wait(timeout=2)
            except subprocess.TimeoutExpired:
                qemu.kill()
                qemu.wait(timeout=2)

    write_rows(args.csv, rows)
    return 0 if rows and rows[-1]["failures"] == 0 else 1


def write_rows(path: Path | None, rows: list[dict[str, int]]) -> None:
    fieldnames = [
        "iteration",
        "stage",
        "fault_target",
        "fault_value",
        "expected",
        "status",
        "value",
        "passes",
        "failures",
    ]
    output = open(path, "w", newline="",
                  encoding="utf-8") if path else sys.stdout
    try:
        writer = csv.DictWriter(output, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)
    finally:
        if path:
            output.close()


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Run QEMU/GDB-RSP fault-injection campaigns against TMR harness firmware.",
    )
    parser.add_argument("--elf", type=Path, required=True,
                        help="Harness ELF built by `zig build harness`.")
    parser.add_argument("--iterations", type=int, default=20)
    parser.add_argument(
        "--campaign",
        choices=("mixed", "none", "single-a", "all-distinct"),
        default="mixed",
    )
    parser.add_argument("--csv", type=Path,
                        help="Write campaign results to this CSV path.")
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--port", type=int, default=1234)
    parser.add_argument("--connect-timeout", type=float, default=10.0)
    parser.add_argument("--stop-timeout", type=float, default=10.0)
    parser.add_argument("--launch-qemu", action="store_true",
                        help="Launch QEMU before connecting.")
    parser.add_argument("--qemu", default="qemu-system-arm")
    parser.add_argument("--gdb", default="gdb")
    parser.add_argument("--qemu-startup-delay", type=float, default=0.5)
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(sys.argv[1:] if argv is None else argv)
    return run_campaign(args)


if __name__ == "__main__":
    raise SystemExit(main())

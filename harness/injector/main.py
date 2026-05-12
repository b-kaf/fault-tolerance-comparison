import argparse
import csv
import socket
import subprocess
import sys
import time
from pathlib import Path
from typing import Callable

from injector.gdbmi import GdbMi


FAULT_NONE = 0
FAULT_COPY_A = 1
FAULT_ALL_DISTINCT = 2
FAULT_ACTIVE_VALUE = 10
FAULT_ACTIVE_LENGTH = 11
FAULT_ACTIVE_CHECKSUM = 12
FAULT_CHECKPOINT_VALUE = 13
FAULT_CHECKPOINT_CHECKSUM = 14
FAULT_ACTIVE_VALUE_AND_CHECKPOINT_CHECKSUM = 15
FAULT_RECOVERY_PRIMARY_VALUE = 20
FAULT_RECOVERY_PRIMARY_CHECKSUM = 21
FAULT_RECOVERY_PRIMARY_VALUE_AND_ALTERNATE_CHECKSUM = 22
FAULT_RECOVERY_PRIMARY_VALUE_AND_CHECKPOINT_CHECKSUM = 23
FAULT_CONTROL_PHASE = 30
FAULT_CONTROL_SIGNATURE = 31
FAULT_CONTROL_SKIP_COMPUTE = 32
FAULT_CONTROL_REPEAT_READ = 33
FAULT_CONTROL_EARLY_TERMINAL = 34

CONTROL_PHASE_COMMIT = 4

# TMR fault values depend on the iteration's expected pattern, so each entry
# is a callable: expected -> (fault_target, fault_value).
TMR_CAMPAIGNS: dict[str, Callable[[int], tuple[int, int]]] = {
    "none": lambda exp: (FAULT_NONE, 0),
    "single-a": lambda exp: (FAULT_COPY_A, exp ^ 0xFFFFFFFF),
    "all-distinct": lambda exp: (FAULT_ALL_DISTINCT, exp ^ 0x13579BDF),
}
TMR_MIXED_ORDER: tuple[str, ...] = ("none", "single-a", "all-distinct")

# Checkpoint faults are independent of iteration/expected, so a static map.
# Any campaign not listed here (e.g. "mixed", "probe-mixed-radiation") rotates
# through CHECKPOINT_MIXED_ORDER per iteration.
CHECKPOINT_CAMPAIGNS: dict[str, tuple[int, int]] = {
    "none":                           (FAULT_NONE, 0),
    "probe-clean-cruise":             (FAULT_NONE, 0),
    "probe-active-bitflip":           (FAULT_ACTIVE_VALUE, 0xFFFFFFFF),
    "probe-telemetry-length-corrupt": (FAULT_ACTIVE_LENGTH, 0xFFFFFFFF),
    "probe-active-checksum-corrupt":  (FAULT_ACTIVE_CHECKSUM, 0x10),
    "probe-stale-checkpoint":         (FAULT_CHECKPOINT_CHECKSUM, 0x10),
    "probe-double-corruption":        (FAULT_ACTIVE_VALUE_AND_CHECKPOINT_CHECKSUM, 0xFFFFFFFF),
}
CHECKPOINT_MIXED_ORDER: tuple[str, ...] = (
    "none",
    "probe-active-bitflip",
    "probe-telemetry-length-corrupt",
    "probe-active-checksum-corrupt",
    "probe-stale-checkpoint",
    "probe-double-corruption",
)
CHECKPOINT_PROBE_CHOICES: tuple[str, ...] = tuple(
    name for name in CHECKPOINT_CAMPAIGNS if name.startswith("probe-")
) + ("probe-mixed-radiation",)

# Recovery-block campaigns inject after the primary result and before the
# acceptance test. Compound faults keep the primary rejection explicit so the
# alternate or restore path is actually exercised.
RECOVERY_BLOCK_CAMPAIGNS: dict[str, tuple[int, int]] = {
    "none":                         (FAULT_NONE, 0),
    "recovery-clean-primary":       (FAULT_NONE, 0),
    "recovery-primary-range":       (FAULT_RECOVERY_PRIMARY_VALUE, 0xFFFFFFFF),
    "recovery-primary-checksum":    (FAULT_RECOVERY_PRIMARY_CHECKSUM, 0x10),
    "recovery-alternate-checksum":  (FAULT_RECOVERY_PRIMARY_VALUE_AND_ALTERNATE_CHECKSUM, 0xFFFFFFFF),
    "recovery-restore-failure":     (FAULT_RECOVERY_PRIMARY_VALUE_AND_CHECKPOINT_CHECKSUM, 0xFFFFFFFF),
}
RECOVERY_BLOCK_MIXED_ORDER: tuple[str, ...] = (
    "none",
    "recovery-primary-range",
    "recovery-primary-checksum",
    "recovery-alternate-checksum",
    "recovery-restore-failure",
)
RECOVERY_BLOCK_CHOICES: tuple[str, ...] = tuple(
    name for name in RECOVERY_BLOCK_CAMPAIGNS if name.startswith("recovery-")
) + ("recovery-mixed-radiation",)

CONTROL_FLOW_CAMPAIGNS: dict[str, tuple[int, int]] = {
    "none":                       (FAULT_NONE, 0),
    "control-clean-path":         (FAULT_NONE, 0),
    "control-phase-corrupt":      (FAULT_CONTROL_PHASE, CONTROL_PHASE_COMMIT),
    "control-signature-corrupt":  (FAULT_CONTROL_SIGNATURE, 0x10),
    "control-skip-compute":       (FAULT_CONTROL_SKIP_COMPUTE, 0),
    "control-repeat-read":        (FAULT_CONTROL_REPEAT_READ, 0),
    "control-early-terminal":     (FAULT_CONTROL_EARLY_TERMINAL, 0),
}
CONTROL_FLOW_MIXED_ORDER: tuple[str, ...] = (
    "none",
    "control-phase-corrupt",
    "control-signature-corrupt",
    "control-skip-compute",
    "control-repeat-read",
    "control-early-terminal",
)
CONTROL_FLOW_CHOICES: tuple[str, ...] = tuple(
    name for name in CONTROL_FLOW_CAMPAIGNS if name.startswith("control-")
) + ("control-mixed-radiation",)


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
    try:
        wait_for_gdb_port(proc, args.host, args.port,
                          args.qemu_startup_timeout)
    except BaseException:
        proc.kill()
        proc.wait(timeout=2)
        raise
    return proc


def wait_for_gdb_port(
    proc: subprocess.Popen[bytes],
    host: str,
    port: int,
    timeout: float,
) -> None:
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        if proc.poll() is not None:
            stderr = proc.stderr.read().decode(
                "utf-8", errors="replace") if proc.stderr else ""
            raise SystemExit(
                f"QEMU exited early with status {proc.returncode}\n{stderr}")
        try:
            with socket.create_connection((host, port), timeout=0.25):
                return
        except OSError:
            time.sleep(0.025)
    raise SystemExit(
        f"QEMU did not open GDB port {host}:{port} within {timeout:.1f}s")


def infer_implementation(elf: Path) -> str:
    name = elf.name.lower()
    if "zig" in name:
        return "zig"
    if "-c-" in name or name.startswith("c-") or name.endswith("-c-m4.elf"):
        return "c"
    return "unknown"


def choose_tmr_fault(campaign: str, iteration: int, expected: int) -> tuple[int, int]:
    chooser = TMR_CAMPAIGNS.get(campaign)
    if chooser is not None:
        return chooser(expected)
    key = TMR_MIXED_ORDER[(iteration - 1) % len(TMR_MIXED_ORDER)]
    return TMR_CAMPAIGNS[key](expected)


def choose_checkpoint_fault(campaign: str, iteration: int) -> tuple[int, int]:
    entry = CHECKPOINT_CAMPAIGNS.get(campaign)
    if entry is not None:
        return entry
    key = CHECKPOINT_MIXED_ORDER[(iteration - 1) % len(CHECKPOINT_MIXED_ORDER)]
    return CHECKPOINT_CAMPAIGNS[key]


def choose_recovery_block_fault(campaign: str, iteration: int) -> tuple[int, int]:
    entry = RECOVERY_BLOCK_CAMPAIGNS.get(campaign)
    if entry is not None:
        return entry
    key = RECOVERY_BLOCK_MIXED_ORDER[(iteration - 1) % len(RECOVERY_BLOCK_MIXED_ORDER)]
    return RECOVERY_BLOCK_CAMPAIGNS[key]


def choose_control_flow_fault(campaign: str, iteration: int) -> tuple[int, int]:
    entry = CONTROL_FLOW_CAMPAIGNS.get(campaign)
    if entry is not None:
        return entry
    key = CONTROL_FLOW_MIXED_ORDER[(iteration - 1) % len(CONTROL_FLOW_MIXED_ORDER)]
    return CONTROL_FLOW_CAMPAIGNS[key]


def run_campaign(args: argparse.Namespace) -> int:
    if args.technique == "checkpoint":
        return run_checkpoint_campaign(args)
    if args.technique == "recovery-block":
        return run_recovery_block_campaign(args)
    if args.technique == "control-flow":
        return run_control_flow_campaign(args)
    return run_tmr_campaign(args)


def run_tmr_campaign(args: argparse.Namespace) -> int:
    qemu = start_qemu(args) if args.launch_qemu else None
    rows = []
    implementation = infer_implementation(args.elf)

    try:
        gdb = GdbMi(args)
        try:
            breakpoints = gdb.install_tmr_breakpoints()

            for _ in range(args.iterations):
                gdb.continue_until_breakpoint(breakpoints.after_init)

                iteration = gdb.read_u32("harness_iteration")
                expected = gdb.read_u32("harness_last_expected")
                fault_target, fault_value = choose_tmr_fault(
                    args.campaign, iteration, expected)
                gdb.write_u32("harness_fault_value", fault_value)
                gdb.write_u32("harness_fault_target", fault_target)

                gdb.continue_until_breakpoint(breakpoints.after_read)

                row = {
                    "technique": "tmr",
                    "implementation": implementation,
                    "campaign": args.campaign,
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


def run_checkpoint_campaign(args: argparse.Namespace) -> int:
    qemu = start_qemu(args) if args.launch_qemu else None
    rows = []
    implementation = infer_implementation(args.elf)

    try:
        gdb = GdbMi(args)
        try:
            breakpoints = gdb.install_checkpoint_breakpoints()

            for _ in range(args.iterations):
                gdb.continue_until_breakpoint(breakpoints.after_mutation)

                iteration = gdb.read_u32("harness_iteration")
                fault_target, fault_value = choose_checkpoint_fault(
                    args.campaign, iteration)
                gdb.write_u32("harness_fault_value", fault_value)
                gdb.write_u32("harness_fault_target", fault_target)

                gdb.continue_until_breakpoint(breakpoints.after_commit)

                row = {
                    "technique": "checkpoint",
                    "implementation": implementation,
                    "campaign": args.campaign,
                    "iteration": iteration,
                    "stage": gdb.read_u32("harness_stage"),
                    "fault_target": gdb.read_u32("harness_last_fault_target"),
                    "fault_value": fault_value & 0xFFFFFFFF,
                    "initial_value": gdb.read_u32("harness_last_initial_value"),
                    "expected": gdb.read_u32("harness_last_expected"),
                    "status": gdb.read_u32("harness_last_status"),
                    "restart_status": gdb.read_u32("harness_last_restart_status"),
                    "active_check": gdb.read_u32("harness_last_active_check"),
                    "checkpoint_check": gdb.read_u32("harness_last_checkpoint_check"),
                    "value": gdb.read_u32("harness_last_value"),
                    "active_value": gdb.read_u32("harness_last_active_value"),
                    "checkpoint_value": gdb.read_u32("harness_last_checkpoint_value"),
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


def run_recovery_block_campaign(args: argparse.Namespace) -> int:
    qemu = start_qemu(args) if args.launch_qemu else None
    rows = []
    implementation = infer_implementation(args.elf)

    try:
        gdb = GdbMi(args)
        try:
            breakpoints = gdb.install_recovery_block_breakpoints()

            for _ in range(args.iterations):
                gdb.continue_until_breakpoint(breakpoints.before_recovery)

                iteration = gdb.read_u32("harness_iteration")
                fault_target, fault_value = choose_recovery_block_fault(
                    args.campaign, iteration)
                gdb.write_u32("harness_fault_value", fault_value)
                gdb.write_u32("harness_fault_target", fault_target)

                gdb.continue_until_breakpoint(breakpoints.after_recovery)

                row = {
                    "technique": "recovery-block",
                    "implementation": implementation,
                    "campaign": args.campaign,
                    "iteration": iteration,
                    "stage": gdb.read_u32("harness_stage"),
                    "fault_target": gdb.read_u32("harness_last_fault_target"),
                    "fault_value": fault_value & 0xFFFFFFFF,
                    "initial_value": gdb.read_u32("harness_last_initial_value"),
                    "expected": gdb.read_u32("harness_last_expected"),
                    "status": gdb.read_u32("harness_last_status"),
                    "recovery_status": gdb.read_u32("harness_last_recovery_status"),
                    "checkpoint_check": gdb.read_u32("harness_last_checkpoint_check"),
                    "primary_check": gdb.read_u32("harness_last_primary_check"),
                    "restore_check": gdb.read_u32("harness_last_restore_check"),
                    "alternate_check": gdb.read_u32("harness_last_alternate_check"),
                    "value": gdb.read_u32("harness_last_value"),
                    "active_value": gdb.read_u32("harness_last_active_value"),
                    "checkpoint_value": gdb.read_u32("harness_last_checkpoint_value"),
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


def run_control_flow_campaign(args: argparse.Namespace) -> int:
    qemu = start_qemu(args) if args.launch_qemu else None
    rows = []
    implementation = infer_implementation(args.elf)

    try:
        gdb = GdbMi(args)
        try:
            breakpoints = gdb.install_control_flow_breakpoints()

            for _ in range(args.iterations):
                gdb.continue_until_breakpoint(breakpoints.before_control_flow)

                iteration = gdb.read_u32("harness_iteration")
                fault_target, fault_value = choose_control_flow_fault(
                    args.campaign, iteration)
                gdb.write_u32("harness_fault_value", fault_value)
                gdb.write_u32("harness_fault_target", fault_target)

                gdb.continue_until_breakpoint(breakpoints.after_control_flow)

                row = {
                    "technique": "control-flow",
                    "implementation": implementation,
                    "campaign": args.campaign,
                    "iteration": iteration,
                    "stage": gdb.read_u32("harness_stage"),
                    "fault_target": gdb.read_u32("harness_last_fault_target"),
                    "fault_value": fault_value & 0xFFFFFFFF,
                    "expected": gdb.read_u32("harness_last_expected"),
                    "status": gdb.read_u32("harness_last_status"),
                    "control_status": gdb.read_u32("harness_last_control_status"),
                    "terminal_status": gdb.read_u32("harness_last_terminal_status"),
                    "phase": gdb.read_u32("harness_last_phase"),
                    "signature": gdb.read_u32("harness_last_signature"),
                    "transitions": gdb.read_u32("harness_last_transitions"),
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


def write_rows(path: Path | None, rows: list[dict[str, object]]) -> None:
    preferred_fieldnames = [
        "technique",
        "implementation",
        "campaign",
        "iteration",
        "stage",
        "fault_target",
        "fault_value",
        "initial_value",
        "expected",
        "status",
        "restart_status",
        "recovery_status",
        "control_status",
        "terminal_status",
        "active_check",
        "checkpoint_check",
        "primary_check",
        "restore_check",
        "alternate_check",
        "phase",
        "signature",
        "transitions",
        "value",
        "active_value",
        "checkpoint_value",
        "passes",
        "failures",
    ]
    fieldnames = [
        field for field in preferred_fieldnames
        if any(field in row for row in rows)
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
        description="Run QEMU/GDB-RSP fault-injection campaigns against harness firmware.",
    )
    parser.add_argument("--elf", type=Path, required=True,
                        help="Harness ELF built by `zig build harness`.")
    parser.add_argument("--iterations", type=int, default=20)
    parser.add_argument(
        "--technique",
        choices=("tmr", "checkpoint", "recovery-block", "control-flow"),
        default="tmr",
        help="Harness technique ABI to drive.",
    )
    parser.add_argument(
        "--campaign",
        choices=(
            "mixed",
            "none",
            "single-a",
            "all-distinct",
            *CHECKPOINT_PROBE_CHOICES,
            *RECOVERY_BLOCK_CHOICES,
            *CONTROL_FLOW_CHOICES,
        ),
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
    parser.add_argument(
        "--qemu-startup-timeout",
        type=float,
        default=10.0,
        help="Seconds to wait for QEMU's GDB-RSP port to accept connections.",
    )
    args = parser.parse_args(argv)

    if args.technique == "tmr" and (
        args.campaign in CHECKPOINT_PROBE_CHOICES
        or args.campaign in RECOVERY_BLOCK_CHOICES
        or args.campaign in CONTROL_FLOW_CHOICES
    ):
        parser.error("probe-* campaigns require --technique checkpoint; "
                     "recovery-* campaigns require --technique recovery-block; "
                     "control-* campaigns require --technique control-flow")
    if args.technique == "checkpoint" and (
        args.campaign in ("single-a", "all-distinct")
        or args.campaign in RECOVERY_BLOCK_CHOICES
        or args.campaign in CONTROL_FLOW_CHOICES
    ):
        parser.error("single-a/all-distinct campaigns require --technique tmr; "
                     "recovery-* campaigns require --technique recovery-block; "
                     "control-* campaigns require --technique control-flow")
    if args.technique == "recovery-block" and (
        args.campaign in ("single-a", "all-distinct")
        or args.campaign in CHECKPOINT_PROBE_CHOICES
        or args.campaign in CONTROL_FLOW_CHOICES
    ):
        parser.error("single-a/all-distinct campaigns require --technique tmr; "
                     "probe-* campaigns require --technique checkpoint; "
                     "control-* campaigns require --technique control-flow")
    if args.technique == "control-flow" and (
        args.campaign in ("single-a", "all-distinct")
        or args.campaign in CHECKPOINT_PROBE_CHOICES
        or args.campaign in RECOVERY_BLOCK_CHOICES
    ):
        parser.error("single-a/all-distinct campaigns require --technique tmr; "
                     "probe-* campaigns require --technique checkpoint; "
                     "recovery-* campaigns require --technique recovery-block")

    return args


def main(argv: list[str] | None = None) -> int:
    args = parse_args(sys.argv[1:] if argv is None else argv)
    return run_campaign(args)


if __name__ == "__main__":
    raise SystemExit(main())

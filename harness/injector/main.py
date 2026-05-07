import argparse
import csv
import subprocess
import sys
import time
from dataclasses import dataclass
from pathlib import Path
from typing import Any

from pygdbmi.gdbcontroller import GdbController


FAULT_NONE = 0
FAULT_COPY_A = 1
FAULT_COPY_B = 2
FAULT_COPY_C = 3
FAULT_ALL_DISTINCT = 4


def mi_quote(value: str) -> str:
    return '"' + value.replace("\\", "\\\\").replace('"', '\\"') + '"'


def parse_u32(value: str) -> int:
    value = value.strip()
    if value.startswith("(uint32_t)"):
        value = value.removeprefix("(uint32_t)").strip()
    return int(value, 0) & 0xFFFFFFFF


@dataclass
class Breakpoints:
    after_init: str
    after_read: str


class GdbMi:
    def __init__(self, args: argparse.Namespace):
        self.stop_timeout = args.stop_timeout
        self.gdb = GdbController(
            command=[
                args.gdb,
                "--interpreter=mi2",
                "--nx",
                "--quiet",
            ],
            time_to_check_for_additional_output_sec=0.05,
        )
        self._drain()
        self._write(f"-file-exec-and-symbols {mi_quote(str(args.elf))}")
        self._write("-gdb-set confirm off")
        self._write("-gdb-set pagination off")
        self._write("set architecture armv7e-m", allow_error=True)
        self._write(
            f"-target-select remote {args.host}:{args.port}", timeout=args.connect_timeout)

    def close(self) -> None:
        self.gdb.exit()

    def install_breakpoints(self) -> Breakpoints:
        after_init = self._insert_breakpoint(
            "harness_injection_point_after_init")
        after_read = self._insert_breakpoint(
            "harness_injection_point_after_read")
        return Breakpoints(after_init=after_init, after_read=after_read)

    def continue_until_breakpoint(self, breakpoint_number: str) -> dict[str, Any]:
        responses = self._write(
            "-exec-continue", timeout=0.1, allow_timeout=True)
        stop = self._find_stop(responses) or self._wait_for_stop()
        actual = stop.get("bkptno")
        if actual != breakpoint_number:
            frame = stop.get("frame") or {}
            where = frame.get("func") or frame.get("addr") or "unknown"
            raise RuntimeError(
                f"expected breakpoint {breakpoint_number}, stopped at {actual or where}"
            )
        return stop

    def read_u32(self, name: str) -> int:
        expression = f"*(unsigned int *)&{name}"
        response = self._write(
            f"-data-evaluate-expression {mi_quote(expression)}")
        value = self._result_payload(response).get("value")
        if not isinstance(value, str):
            raise RuntimeError(
                f"no scalar value returned for {name}: {response}")
        return parse_u32(value)

    def write_u32(self, name: str, value: int) -> None:
        command = f"set {{unsigned int}}&{name} = {value & 0xFFFFFFFF}"
        self._write(f"-interpreter-exec console {mi_quote(command)}")

    def _insert_breakpoint(self, symbol: str) -> str:
        response = self._write(f"-break-insert -h {symbol}")
        bkpt = self._result_payload(response).get("bkpt")
        if not isinstance(bkpt, dict) or "number" not in bkpt:
            raise RuntimeError(
                f"could not install breakpoint for {symbol}: {response}")
        return str(bkpt["number"])

    def _wait_for_stop(self) -> dict[str, Any]:
        deadline = time.monotonic() + self.stop_timeout
        while time.monotonic() < deadline:
            timeout = min(1.0, max(0.01, deadline - time.monotonic()))
            responses = self.gdb.get_gdb_response(
                timeout_sec=timeout,
                raise_error_on_timeout=False,
            )
            stop = self._find_stop(responses)
            if stop is not None:
                return stop
        raise TimeoutError(
            f"target did not stop within {self.stop_timeout:.1f}s")

    def _find_stop(self, responses: list[dict[str, Any]]) -> dict[str, Any] | None:
        for response in responses:
            if response.get("type") == "notify" and response.get("message") == "stopped":
                payload = response.get("payload")
                if isinstance(payload, dict):
                    return payload
                return {}
        return None

    def _write(
        self,
        command: str,
        *,
        timeout: float = 5.0,
        allow_timeout: bool = False,
        allow_error: bool = False,
    ) -> list[dict[str, Any]]:
        responses = self.gdb.write(
            command,
            timeout_sec=timeout,
            raise_error_on_timeout=not allow_timeout,
        )
        if allow_timeout and responses is None:
            return []
        for response in responses:
            if (
                response.get("type") == "result"
                and response.get("message") == "error"
                and not allow_error
            ):
                payload = response.get("payload") or {}
                message = payload.get("msg") if isinstance(
                    payload, dict) else None
                raise RuntimeError(
                    f"GDB command failed: {command}: {message or response}")
        return responses

    def _result_payload(self, responses: list[dict[str, Any]]) -> dict[str, Any]:
        for response in responses:
            if response.get("type") == "result" and response.get("message") == "done":
                payload = response.get("payload")
                if isinstance(payload, dict):
                    return payload
                return {}
        raise RuntimeError(f"GDB command did not return ^done: {responses}")

    def _drain(self) -> None:
        self.gdb.get_gdb_response(
            timeout_sec=0.2, raise_error_on_timeout=False)


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
    if campaign == "single-b":
        return FAULT_COPY_B, expected ^ 0xA5A5A5A5
    if campaign == "single-c":
        return FAULT_COPY_C, expected ^ 0x5A5A5A5A
    if campaign == "all-distinct":
        return FAULT_ALL_DISTINCT, expected ^ 0x13579BDF

    schedule = (
        (FAULT_NONE, 0),
        (FAULT_COPY_A, expected ^ 0xFFFFFFFF),
        (FAULT_COPY_B, expected ^ 0xA5A5A5A5),
        (FAULT_COPY_C, expected ^ 0x5A5A5A5A),
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
        choices=("mixed", "none", "single-a",
                 "single-b", "single-c", "all-distinct"),
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

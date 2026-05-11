import argparse
import time
from dataclasses import dataclass
from typing import Any

from pygdbmi.gdbcontroller import GdbController


def mi_quote(value: str) -> str:
    return '"' + value.replace("\\", "\\\\").replace('"', '\\"') + '"'


def parse_u32(value: str) -> int:
    value = value.strip()
    if value.startswith("(uint32_t)"):
        value = value.removeprefix("(uint32_t)").strip()
    return int(value, 0) & 0xFFFFFFFF


@dataclass
class TmrBreakpoints:
    after_init: str
    after_read: str


@dataclass
class CheckpointBreakpoints:
    after_mutation: str
    after_commit: str


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
        self._write(f"-target-select remote {args.host}:{args.port}", timeout=args.connect_timeout)

    def close(self) -> None:
        self.gdb.exit()

    def install_tmr_breakpoints(self) -> TmrBreakpoints:
        after_init = self._insert_breakpoint("harness_injection_point_after_init")
        after_read = self._insert_breakpoint("harness_injection_point_after_read")
        return TmrBreakpoints(after_init=after_init, after_read=after_read)

    def install_checkpoint_breakpoints(self) -> CheckpointBreakpoints:
        after_mutation = self._insert_breakpoint("harness_injection_point_after_mutation")
        after_commit = self._insert_breakpoint("harness_injection_point_after_commit")
        return CheckpointBreakpoints(after_mutation=after_mutation, after_commit=after_commit)

    def continue_until_breakpoint(self, breakpoint_number: str) -> dict[str, Any]:
        responses = self._write("-exec-continue", timeout=0.1, allow_timeout=True)
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
        response = self._write(f"-data-evaluate-expression {mi_quote(expression)}")
        value = self._result_payload(response).get("value")
        if not isinstance(value, str):
            raise RuntimeError(f"no scalar value returned for {name}: {response}")
        return parse_u32(value)

    def write_u32(self, name: str, value: int) -> None:
        command = f"set {{unsigned int}}&{name} = {value & 0xFFFFFFFF}"
        self._write(f"-interpreter-exec console {mi_quote(command)}")

    def _insert_breakpoint(self, symbol: str) -> str:
        response = self._write(f"-break-insert -h {symbol}")
        bkpt = self._result_payload(response).get("bkpt")
        if not isinstance(bkpt, dict) or "number" not in bkpt:
            raise RuntimeError(f"could not install breakpoint for {symbol}: {response}")
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
        raise TimeoutError(f"target did not stop within {self.stop_timeout:.1f}s")

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
                message = payload.get("msg") if isinstance(payload, dict) else None
                raise RuntimeError(f"GDB command failed: {command}: {message or response}")
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
        self.gdb.get_gdb_response(timeout_sec=0.2, raise_error_on_timeout=False)

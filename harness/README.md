# Fault-Injection Harness

This harness builds two bare-metal Cortex-M4 firmware images for QEMU's
`mps2-an386` machine:

- `tmr-harness-c-m4.elf` exercises `c/tmr/tmr.h`.
- `tmr-harness-zig-m4.elf` exercises `zig/tmr/tmr.zig`.

Both are cross-compiled by Zig through `build.zig`. Shared startup, linker, and
ABI definitions live in `harness/common`; implementation-specific loop harnesses
live in `harness/c` and `harness/zig`.

## Build

```sh
zig build harness
```

The ELFs are installed under `zig-out/harness/`.

## Run A Campaign

```sh
cd harness/injector
uv run python main.py \
  --launch-qemu \
  --elf ../../zig-out/harness/tmr-harness-c-m4.elf \
  --iterations 20

uv run python main.py \
  --launch-qemu \
  --elf ../../zig-out/harness/tmr-harness-zig-m4.elf \
  --iterations 20
```

The injector launches:

```sh
qemu-system-arm -M mps2-an386 -cpu cortex-m4 -kernel <elf> -nographic -S -gdb tcp::<port>
```

It then uses `pygdbmi` to drive GDB/MI. GDB connects to QEMU's GDB Remote Serial
Protocol endpoint, places breakpoints on the exported injection hooks, writes
the fault-control globals, and records the result counters exposed by the
firmware.

## Firmware ABI

Each image runs forever. Every loop iteration:

1. Initializes a TMR value from a deterministic pattern.
2. Calls `harness_injection_point_after_init`.
3. Applies any fault requested through `harness_fault_target` and
   `harness_fault_value`.
4. Reads the TMR value, validates the result, and updates counters.
5. Calls `harness_injection_point_after_read`.

Stable symbols exposed to the injector:

- `harness_injection_point_after_init`
- `harness_injection_point_after_read`
- `harness_iteration`
- `harness_stage`
- `harness_fault_target`
- `harness_fault_value`
- `harness_last_expected`
- `harness_last_value`
- `harness_last_status`
- `harness_passes`
- `harness_failures`
- `harness_last_fault_target`

Fault targets:

- `0`: no fault
- `1`: corrupt copy A
- `2`: corrupt copy B
- `3`: corrupt copy C
- `4`: make all copies distinct

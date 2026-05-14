# Fault-Injection Harness

This harness builds bare-metal Cortex-M4 firmware images for QEMU's
`mps2-an386` machine:

- `tmr-harness-c-m4.elf` exercises `c/tmr/tmr.h`.
- `tmr-harness-zig-m4.elf` exercises `zig/tmr/tmr.zig`.
- `checkpoint-harness-c-m4.elf` exercises `c/checkpoint/checkpoint.h`.
- `checkpoint-harness-zig-m4.elf` exercises `zig/checkpoint/checkpoint.zig`.
- `recovery-block-harness-c-m4.elf` exercises `c/recovery_block/recovery_block.h`.
- `recovery-block-harness-zig-m4.elf` exercises `zig/recovery_block/recovery_block.zig`.
- `control-flow-harness-c-m4.elf` exercises `c/control_flow/control_flow.h`.
- `control-flow-harness-zig-m4.elf` exercises `zig/control_flow/control_flow.zig`.

Both are cross-compiled by Zig through `build.zig`. Shared startup, linker, and
ABI definitions live in `harness/common`; implementation-specific loop harnesses
live in `harness/c` and `harness/zig`.

## Build

```sh
zig build harness
```

The ELFs are installed under `zig-out/harness/`.

## Run A Campaign

From the devenv shell, the shortest form is:

```sh
harness-campaign c tmr
```

The helper takes `<language> <technique>` and always runs the `mixed` campaign
for 10 iterations. Optional third and fourth arguments set the CSV output path
and GDB port:

```sh
harness-campaign c tmr /tmp/tmr-c.csv 12410
harness-campaign zig checkpoint -- /tmp/checkpoint-zig.csv 12411
```

```sh
cd harness/injector
uv run python main.py \
  --launch-qemu \
  --technique tmr \
  --language c \
  --iterations 20

uv run python main.py \
  --launch-qemu \
  --technique tmr \
  --language zig \
  --iterations 20

uv run python main.py \
  --launch-qemu \
  --technique checkpoint \
  --language c \
  --campaign checkpoint-mixed-faults \
  --iterations 20

uv run python main.py \
  --launch-qemu \
  --technique checkpoint \
  --language zig \
  --campaign checkpoint-mixed-faults \
  --iterations 20

uv run python main.py \
  --launch-qemu \
  --technique recovery-block \
  --language c \
  --campaign recovery-mixed-faults \
  --iterations 20

uv run python main.py \
  --launch-qemu \
  --technique recovery-block \
  --language zig \
  --campaign recovery-mixed-faults \
  --iterations 20

uv run python main.py \
  --launch-qemu \
  --technique control-flow \
  --language c \
  --campaign control-mixed-faults \
  --iterations 20

uv run python main.py \
  --launch-qemu \
  --technique control-flow \
  --language zig \
  --campaign control-mixed-faults \
  --iterations 20
```

The injector launches:

```sh
qemu-system-arm -M mps2-an386 -cpu cortex-m4 -kernel <elf> -nographic -S -gdb tcp::<port>
```

The `<elf>` path is inferred as
`zig-out/harness/<technique>-harness-<language>-m4.elf`. The injector then uses
`pygdbmi` to drive GDB/MI. GDB connects to QEMU's GDB Remote Serial Protocol
endpoint, places breakpoints on the exported injection hooks, writes the
fault-control globals, and records the result counters exposed by the firmware.

## Firmware ABI

Each TMR image runs forever. Every loop iteration:

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
- `2`: make all copies distinct

Checkpoint harness images use a generic checked record:

- `tag`: record type;
- `value`: bounded sample value;
- `min` and `max`: accepted value range;
- `length` and `capacity`: record sizing;
- `checksum`: frame integrity check.

Each checkpoint loop iteration:

1. Initializes a valid checked record.
2. Captures it as the last known-good checkpoint.
3. Applies a deterministic valid update to active state.
4. Calls `harness_injection_point_after_mutation`.
5. Applies any requested active/checkpoint corruption.
6. Calls checkpoint `commit_or_restart`, validates the outcome, and updates counters.
7. Calls `harness_injection_point_after_commit`.

Additional stable symbols exposed by checkpoint images:

- `harness_injection_point_after_mutation`
- `harness_injection_point_after_commit`
- `harness_last_initial_value`
- `harness_last_restart_status`
- `harness_last_active_check`
- `harness_last_checkpoint_check`
- `harness_last_active_value`
- `harness_last_checkpoint_value`

Checkpoint fault targets:

- `10`: corrupt active `value`
- `11`: corrupt active `length`
- `12`: corrupt active `checksum`
- `13`: corrupt checkpoint `value`
- `14`: corrupt checkpoint `checksum`
- `15`: corrupt active `value` and checkpoint `checksum`

Recovery-block harness images use the same checked record. Each
iteration:

1. Initializes a valid checked record.
2. Calls `harness_injection_point_before_recovery`.
3. Runs a recovery block with a direct-form primary implementation.
4. Applies any requested primary corruption after the primary result and before
   the acceptance test.
5. Restores the checkpoint and runs a repeated-addition alternate when the
   primary result is rejected.
6. Applies any requested alternate corruption after the alternate result and
   before its acceptance test.
7. Records recovery status, checker statuses, final active/checkpoint values,
   and pass/fail counters.
8. Calls `harness_injection_point_after_recovery`.

Additional stable symbols exposed by recovery-block images:

- `harness_injection_point_before_recovery`
- `harness_injection_point_after_recovery`
- `harness_last_recovery_status`
- `harness_last_checkpoint_check`
- `harness_last_primary_check`
- `harness_last_restore_check`
- `harness_last_alternate_check`
- `harness_last_initial_value`
- `harness_last_active_value`
- `harness_last_checkpoint_value`

Recovery-block fault targets:

- `20`: corrupt primary `value`
- `21`: corrupt primary `checksum`
- `22`: corrupt primary `value` and alternate `checksum`
- `23`: corrupt primary `value` and checkpoint `checksum`

Control-flow harness images monitor an explicit software-signature sequence:

1. `start`
2. `read_input`
3. `compute`
4. `validate`
5. `commit`
6. `done`

Each transition validates the current phase and its expected signature before
advancing. Each iteration:

1. Calls `harness_injection_point_before_control_flow`.
2. Advances through the monitored operation.
3. Applies requested phase or signature corruption after `read_input`, or
   simulates a skipped, repeated, or early-terminal path.
4. Records transition status, terminal status, final phase, signature,
   transition count, value, and pass/fail counters.
5. Calls `harness_injection_point_after_control_flow`.

Additional stable symbols exposed by control-flow images:

- `harness_injection_point_before_control_flow`
- `harness_injection_point_after_control_flow`
- `harness_last_control_status`
- `harness_last_terminal_status`
- `harness_last_phase`
- `harness_last_signature`
- `harness_last_transitions`

Control-flow fault targets:

- `30`: corrupt current phase
- `31`: corrupt current signature
- `32`: skip compute transition
- `33`: repeat read transition
- `34`: finish before reaching `done`

Run QEMU/GDB-RSP fault-injection campaigns against the harness firmware.
This is a uv project and uses `pygdbmi` to drive GDB/MI.

Build firmware first:

```sh
zig build harness
```

Run a mixed campaign against the C implementation:

```sh
uv run python main.py \
  --launch-qemu \
  --elf ../../zig-out/harness/tmr-harness-c-m4.elf \
  --technique tmr \
  --iterations 20
```

Run against the Zig implementation:

```sh
uv run python main.py \
  --launch-qemu \
  --elf ../../zig-out/harness/tmr-harness-zig-m4.elf \
  --technique tmr \
  --iterations 20
```

Run a probe-themed checkpoint/restart campaign:

```sh
uv run python main.py \
  --launch-qemu \
  --elf ../../zig-out/harness/checkpoint-harness-c-m4.elf \
  --technique checkpoint \
  --campaign probe-mixed-radiation \
  --iterations 20

uv run python main.py \
  --launch-qemu \
  --elf ../../zig-out/harness/checkpoint-harness-zig-m4.elf \
  --technique checkpoint \
  --campaign probe-mixed-radiation \
  --iterations 20
```

Run a recovery-block campaign:

```sh
uv run python main.py \
  --launch-qemu \
  --elf ../../zig-out/harness/recovery-block-harness-c-m4.elf \
  --technique recovery-block \
  --campaign recovery-mixed-radiation \
  --iterations 20

uv run python main.py \
  --launch-qemu \
  --elf ../../zig-out/harness/recovery-block-harness-zig-m4.elf \
  --technique recovery-block \
  --campaign recovery-mixed-radiation \
  --iterations 20
```

Run a control-flow checking campaign:

```sh
uv run python main.py \
  --launch-qemu \
  --elf ../../zig-out/harness/control-flow-harness-c-m4.elf \
  --technique control-flow \
  --campaign control-mixed-radiation \
  --iterations 20

uv run python main.py \
  --launch-qemu \
  --elf ../../zig-out/harness/control-flow-harness-zig-m4.elf \
  --technique control-flow \
  --campaign control-mixed-radiation \
  --iterations 20
```

Use `--csv <path>` to save campaign output.

Checkpoint campaigns:

- `probe-clean-cruise`
- `probe-active-bitflip`
- `probe-telemetry-length-corrupt`
- `probe-active-checksum-corrupt`
- `probe-stale-checkpoint`
- `probe-double-corruption`
- `probe-mixed-radiation`

Recovery-block campaigns:

- `recovery-clean-primary`
- `recovery-primary-range`
- `recovery-primary-checksum`
- `recovery-alternate-checksum`
- `recovery-restore-failure`
- `recovery-mixed-radiation`

Control-flow campaigns:

- `control-clean-path`
- `control-phase-corrupt`
- `control-signature-corrupt`
- `control-skip-compute`
- `control-repeat-read`
- `control-early-terminal`
- `control-mixed-radiation`

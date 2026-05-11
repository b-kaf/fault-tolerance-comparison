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

Use `--csv <path>` to save campaign output.

Checkpoint campaigns:

- `probe-clean-cruise`
- `probe-active-bitflip`
- `probe-telemetry-length-corrupt`
- `probe-active-checksum-corrupt`
- `probe-stale-checkpoint`
- `probe-double-corruption`
- `probe-mixed-radiation`

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
  --technique tmr \
  --language c \
  --iterations 20
```

Run against the Zig implementation:

```sh
uv run python main.py \
  --launch-qemu \
  --technique tmr \
  --language zig \
  --iterations 20
```

Run a checkpoint/restart campaign:

```sh
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
```

Run a recovery-block campaign:

```sh
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
```

Run a control-flow checking campaign:

```sh
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

Use `--csv <path>` to save campaign output.
The injector infers the ELF path as
`zig-out/harness/<technique>-harness-<language>-m4.elf`.

Checkpoint campaigns:

- `checkpoint-clean-run`
- `checkpoint-active-value-fault`
- `checkpoint-active-length-fault`
- `checkpoint-active-checksum-fault`
- `checkpoint-saved-checksum-fault`
- `checkpoint-double-fault`
- `checkpoint-mixed-faults`

Recovery-block campaigns:

- `recovery-clean-primary`
- `recovery-primary-range`
- `recovery-primary-checksum`
- `recovery-alternate-checksum`
- `recovery-restore-failure`
- `recovery-mixed-faults`

Control-flow campaigns:

- `control-clean-path`
- `control-phase-corrupt`
- `control-signature-corrupt`
- `control-skip-compute`
- `control-repeat-read`
- `control-early-terminal`
- `control-mixed-faults`

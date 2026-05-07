Run QEMU/GDB-RSP fault-injection campaigns against the TMR harness firmware.
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
  --iterations 20
```

Run against the Zig implementation:

```sh
uv run python main.py \
  --launch-qemu \
  --elf ../../zig-out/harness/tmr-harness-zig-m4.elf \
  --iterations 20
```

Use `--csv <path>` to save campaign output.

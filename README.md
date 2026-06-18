# fault-tolerance-comparison

Comparing software fault-tolerance techniques (TMR, checkpointing, recovery
blocks, control-flow monitoring) implemented in **C** and **Zig**, evaluated by
fault injection against bare-metal Cortex-M4 firmware running under QEMU.

## Setup

The repo ships a reproducible [devenv](https://devenv.sh) shell. The recommended
path is Nix + direnv + devenv; a manual dependency list is given as an
alternative.

### Option A — Nix + direnv + devenv (recommended)

1. **Install Nix.** Either installer works:

   - Determinate Systems installer (recommended, flakes enabled by default):
     <https://docs.determinate.systems/getting-started/>
   - Official installer (enable flakes afterwards):
     <https://nixos.org/download/>

2. **Install direnv** and hook it into your shell — see
   <https://direnv.net/docs/installation.html> and
   <https://direnv.net/docs/hook.html>.

3. **Install devenv:**

   ```sh
   nix profile install nixpkgs#devenv
   ```

4. **Enter the environment.** From the repo root:

   ```sh
   direnv allow
   ```

   direnv loads the devenv shell automatically (every dependency below is
   provided, pinned via `devenv.lock`). Without direnv, run `devenv shell`
   manually.

### Option B — install dependencies manually

If you would rather not use Nix, install the following and put them on your
`PATH`. Versions are the ones the devenv shell pins (`devenv.lock`); nearby
versions will usually work.

| Tool | Version | Notes |
| --- | --- | --- |
| Zig | 0.16.0 | builds the firmware and cross-compiles the C/Zig sources |
| Go | 1.26.2 | builds/runs the harness runner & TUI (`harness/tui`) |
| C compiler (Clang/LLVM) | LLVM 19+ | C sources are compiled via `zig cc` |
| LLVM bintools (optional) | matching LLVM | `llvm-objdump` for inspecting the generated harness assembly |
| QEMU | 10.x (`qemu-system-arm`) | `mps2-an386` Cortex-M4 machine + TCG plugin support |
| GDB | 17.x | drives fault injection over GDB/MI + RSP |
| glib + pkg-config | system | needed to build the QEMU TCG fuzz plugin |

The QEMU TCG fuzz plugin (`plugins/qemu-ft-fuzz`) must be built and its path
exported as `QEMU_FT_FUZZ_PLUGIN`. Under devenv this is done automatically; see
`nix/qemu-ft-fuzz-plugin.nix` for the build command.

## Build & run

```sh
zig build harness        # build the bare-metal harness ELFs
harness-tui              # interactive TUI to drive campaigns (devenv only)
```

### TUI

The runner and interactive TUI are a single Go binary under `harness/tui`. Build
and test it directly with Go:

```sh
go build -C harness/tui ./cmd/harness-tui   # build the binary
go test -C harness/tui ./...                # run the tests
go run -C harness/tui ./cmd/harness-tui     # build and run
```

In the devenv shell, `harness-tui` runs the binary with `QEMU_FT_FUZZ_PLUGIN`
already set.

See [`harness/README.md`](harness/README.md) for the full harness layout,
campaign options, and firmware ABI.

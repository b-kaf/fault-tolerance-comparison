{
  pkgs,
  lib,
  config,
  inputs,
  ...
}:

let
  qemuFtFuzzPlugin = pkgs.callPackage ./nix/qemu-ft-fuzz-plugin.nix { };
in
{

  # https://devenv.sh/packages/
  packages = [
    pkgs.gdb
    pkgs.git
    pkgs.nixfmt
    pkgs.llvmPackages.bintools
    pkgs.qemu
    pkgs.uv
    qemuFtFuzzPlugin
  ];

  # https://devenv.sh/languages/
  languages.nix.enable = true;
  languages.zig.enable = true;
  languages.c.enable = true;

  # https://devenv.sh/processes/
  # processes.dev.exec = "${lib.getExe pkgs.watchexec} -n -- ls -la";

  # https://devenv.sh/services/
  # services.postgres.enable = true;

  # https://devenv.sh/scripts/
  scripts.harness-build.exec = ''
    zig build harness
  '';
  scripts.harness-campaign.exec = ''
    set -eu

    language="''${1:-}"
    technique="''${2:-}"

    if [ -z "$language" ] || [ -z "$technique" ]; then
      echo "usage: harness-campaign <c|zig> <tmr|checkpoint|recovery-block|control-flow>" >&2
      exit 2
    fi

    zig build harness

    uv run --directory harness/e2e/injector python main.py \
      --language "$language" \
      --technique "$technique" \
      --campaign mixed \
      --iterations 10
  '';
  scripts.harness-fuzz-campaign.exec = ''
    set -eu

    language="''${1:-}"
    technique="''${2:-}"
    campaign="''${3:-reg-bitflip-window}"
    trials="''${4:-20}"
    seed="''${5:-0xC0DEC0DE}"

    if [ -z "$language" ] || [ -z "$technique" ]; then
      echo "usage: harness-fuzz-campaign <c|zig> <tmr|checkpoint|recovery-block|control-flow> [none|ram-symbol-bitflip|reg-bitflip-window] [trials] [seed]" >&2
      exit 2
    fi

    zig build fuzz-harness

    QEMU_FT_FUZZ_PLUGIN="${qemuFtFuzzPlugin}/lib/qemu-ft-fuzz.so" \
      uv run --directory harness/fuzz/runner python main.py \
        --language "$language" \
        --technique "$technique" \
        --campaign "$campaign" \
        --seed "$seed" \
        --trials "''${ITERATIONS:-$trials}"
  '';
  scripts.harness-asm.exec = ''
    set -eu

    asm_dir="''${ASM_DIR:-results/asm}"
    mkdir -p "$asm_dir"
    asm_dir="$(cd "$asm_dir" && pwd)"

    zig build harness "''${@}"

    disassemble() {
      name="$1"
      elf="$2"
      out="$asm_dir/$name.s"

      echo "disassembling $elf -> $out"
      llvm-objdump -d --demangle --print-imm-hex "$elf" > "$out"
    }

    disassemble tmr-c-m4 zig-out/harness/tmr-harness-c-m4.elf
    disassemble tmr-zig-m4 zig-out/harness/tmr-harness-zig-m4.elf
    disassemble checkpoint-c-m4 zig-out/harness/checkpoint-harness-c-m4.elf
    disassemble checkpoint-zig-m4 zig-out/harness/checkpoint-harness-zig-m4.elf
    disassemble recovery-block-zig-m4 zig-out/harness/recovery-block-harness-zig-m4.elf
    disassemble recovery-block-c-m4 zig-out/harness/recovery-block-harness-c-m4.elf

    echo "assembly output written to $asm_dir"
  '';
  # See full reference at https://devenv.sh/reference/options/
}

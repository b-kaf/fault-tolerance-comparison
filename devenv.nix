{
  pkgs,
  lib,
  config,
  inputs,
  ...
}:

{

  # https://devenv.sh/packages/
  packages = [
    pkgs.git
    pkgs.nixfmt
    pkgs.llvmPackages.bintools
    pkgs.qemu
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

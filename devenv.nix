{ pkgs, lib, config, inputs, ... }:

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

    echo "assembly output written to $asm_dir"
  '';
  scripts.campaign-tmr-c.exec = ''
    zig build harness
    cd harness/injector
    uv run python main.py \
      --launch-qemu \
      --technique tmr \
      --port "''${TMR_CAMPAIGN_C_PORT:-1245}" \
      --iterations "''${TMR_CAMPAIGN_ITERATIONS:-20}" \
      --elf ../../zig-out/harness/tmr-harness-c-m4.elf \
      "''${@}"
  '';
  scripts.campaign-tmr-zig.exec = ''
    zig build harness
    cd harness/injector
    uv run python main.py \
      --launch-qemu \
      --technique tmr \
      --port "''${TMR_CAMPAIGN_ZIG_PORT:-1246}" \
      --iterations "''${TMR_CAMPAIGN_ITERATIONS:-20}" \
      --elf ../../zig-out/harness/tmr-harness-zig-m4.elf \
      "''${@}"
  '';
  scripts.campaign-tmr-all.exec = ''
    campaign-tmr-c "''${@}"
    campaign-tmr-zig "''${@}"
  '';
  scripts.campaign-checkpoint-c.exec = ''
    zig build harness
    cd harness/injector
    uv run python main.py \
      --launch-qemu \
      --technique checkpoint \
      --campaign "''${CHECKPOINT_CAMPAIGN:-probe-mixed-radiation}" \
      --port "''${CHECKPOINT_CAMPAIGN_C_PORT:-1255}" \
      --iterations "''${CHECKPOINT_CAMPAIGN_ITERATIONS:-20}" \
      --elf ../../zig-out/harness/checkpoint-harness-c-m4.elf \
      "''${@}"
  '';
  scripts.campaign-checkpoint-zig.exec = ''
    zig build harness
    cd harness/injector
    uv run python main.py \
      --launch-qemu \
      --technique checkpoint \
      --campaign "''${CHECKPOINT_CAMPAIGN:-probe-mixed-radiation}" \
      --port "''${CHECKPOINT_CAMPAIGN_ZIG_PORT:-1256}" \
      --iterations "''${CHECKPOINT_CAMPAIGN_ITERATIONS:-20}" \
      --elf ../../zig-out/harness/checkpoint-harness-zig-m4.elf \
      "''${@}"
  '';
  scripts.campaign-checkpoint-all.exec = ''
    campaign-checkpoint-c "''${@}"
    campaign-checkpoint-zig "''${@}"
  '';
  scripts.campaign-c.exec = ''
    campaign-tmr-c "''${@}"
  '';
  scripts.campaign-zig.exec = ''
    campaign-tmr-zig "''${@}"
  '';
  scripts.campaign-all.exec = ''
    campaign-tmr-all "''${@}"
  '';
  scripts.campaign-results.exec = ''
    set -eu

    results_dir="''${RESULTS_DIR:-results}"
    mkdir -p "$results_dir"
    results_dir="$(cd "$results_dir" && pwd)"

    tmr_iterations="''${TMR_CAMPAIGN_ITERATIONS:-''${CAMPAIGN_ITERATIONS:-20}}"
    checkpoint_iterations="''${CHECKPOINT_CAMPAIGN_ITERATIONS:-''${CAMPAIGN_ITERATIONS:-20}}"

    zig build harness
    cd harness/injector

    run_campaign() {
      technique="$1"
      implementation="$2"
      campaign="$3"
      iterations="$4"
      port="$5"
      elf="$6"
      output="$7"

      echo "running $technique/$implementation/$campaign -> $output"
      uv run python main.py \
        --launch-qemu \
        --technique "$technique" \
        --campaign "$campaign" \
        --iterations "$iterations" \
        --port "$port" \
        --elf "$elf" \
        --csv "$output"
    }

    for campaign in none single-a all-distinct mixed; do
      run_campaign \
        tmr \
        c \
        "$campaign" \
        "$tmr_iterations" \
        "''${TMR_CAMPAIGN_C_PORT:-1245}" \
        ../../zig-out/harness/tmr-harness-c-m4.elf \
        "$results_dir/tmr-c-$campaign.csv"

      run_campaign \
        tmr \
        zig \
        "$campaign" \
        "$tmr_iterations" \
        "''${TMR_CAMPAIGN_ZIG_PORT:-1246}" \
        ../../zig-out/harness/tmr-harness-zig-m4.elf \
        "$results_dir/tmr-zig-$campaign.csv"
    done

    for campaign in \
      probe-clean-cruise \
      probe-active-bitflip \
      probe-telemetry-length-corrupt \
      probe-active-checksum-corrupt \
      probe-stale-checkpoint \
      probe-double-corruption \
      probe-mixed-radiation
    do
      run_campaign \
        checkpoint \
        c \
        "$campaign" \
        "$checkpoint_iterations" \
        "''${CHECKPOINT_CAMPAIGN_C_PORT:-1255}" \
        ../../zig-out/harness/checkpoint-harness-c-m4.elf \
        "$results_dir/checkpoint-c-$campaign.csv"

      run_campaign \
        checkpoint \
        zig \
        "$campaign" \
        "$checkpoint_iterations" \
        "''${CHECKPOINT_CAMPAIGN_ZIG_PORT:-1256}" \
        ../../zig-out/harness/checkpoint-harness-zig-m4.elf \
        "$results_dir/checkpoint-zig-$campaign.csv"
    done

    echo "campaign results written to $results_dir"
  '';

  # https://devenv.sh/tasks/
  # tasks = {
  #   "myproj:setup".exec = "mytool build";
  #   "devenv:enterShell".after = [ "myproj:setup" ];
  # };

  # https://devenv.sh/git-hooks/
  # git-hooks.hooks.shellcheck.enable = true;

  # See full reference at https://devenv.sh/reference/options/
}

{ pkgs, lib, config, inputs, ... }:

{
  # https://devenv.sh/basics/
  env.GREET = "devenv";

  # https://devenv.sh/packages/
  packages = [ pkgs.git ];

  # https://devenv.sh/languages/
  languages.nix.enable = true;
  languages.zig.enable = true;
  languages.c.enable = true;

  # https://devenv.sh/processes/
  # processes.dev.exec = "${lib.getExe pkgs.watchexec} -n -- ls -la";

  # https://devenv.sh/services/
  # services.postgres.enable = true;

  # https://devenv.sh/scripts/
  scripts.hello.exec = ''
    echo hello from $GREET
  '';
  scripts.test-zig.exec = ''
    zig build test
  '';
  scripts.test-c.exec = ''
    cc -std=c11 -Wall -Wextra -pedantic -o /tmp/tmr_test c/tmr/tmr_test.c
    /tmp/tmr_test
  '';
  scripts.harness-build.exec = ''
    zig build harness
  '';
  scripts.campaign-c.exec = ''
    zig build harness
    cd harness/injector
    uv run python main.py \
      --launch-qemu \
      --port "''${TMR_CAMPAIGN_C_PORT:-1245}" \
      --iterations "''${TMR_CAMPAIGN_ITERATIONS:-20}" \
      --elf ../../zig-out/harness/tmr-harness-c-m4.elf \
      "''${@}"
  '';
  scripts.campaign-zig.exec = ''
    zig build harness
    cd harness/injector
    uv run python main.py \
      --launch-qemu \
      --port "''${TMR_CAMPAIGN_ZIG_PORT:-1246}" \
      --iterations "''${TMR_CAMPAIGN_ITERATIONS:-20}" \
      --elf ../../zig-out/harness/tmr-harness-zig-m4.elf \
      "''${@}"
  '';
  scripts.campaign-all.exec = ''
    campaign-c "''${@}"
    campaign-zig "''${@}"
  '';

  # https://devenv.sh/basics/
  enterShell = ''
    hello         # Run scripts directly
    git --version # Use packages
  '';

  # https://devenv.sh/tasks/
  # tasks = {
  #   "myproj:setup".exec = "mytool build";
  #   "devenv:enterShell".after = [ "myproj:setup" ];
  # };

  # https://devenv.sh/tests/
  enterTest = ''
    echo "Running tests"
    git --version | grep --color=auto "${pkgs.git.version}"
  '';

  # https://devenv.sh/git-hooks/
  # git-hooks.hooks.shellcheck.enable = true;

  # See full reference at https://devenv.sh/reference/options/
}

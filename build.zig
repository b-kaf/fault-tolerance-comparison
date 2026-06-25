const std = @import("std");

const Import = struct {
    name: []const u8,
    module: *std.Build.Module,
};

// TargetProfile captures everything ISA-specific about a harness firmware build,
// so the same harness set can be emitted for multiple targets (ARM Cortex-M4 on
// mps2-an386, RISC-V rv32 on virt) by iterating over a profile table.
const TargetProfile = struct {
    target: std.Build.ResolvedTarget,
    suffix: []const u8, // ELF name suffix, e.g. "m4" / "rv32"
    startup: []const u8, // startup assembly path
    linker: []const u8, // linker script path
    entry: []const u8, // entry symbol name
};

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const test_step = b.step("test", "Run all tests");

    const tmr_mod = makeZigModule(b, "zig/tmr/tmr.zig", &.{}, target, optimize);
    const checker_mod = makeZigModule(b, "zig/checker/checker.zig", &.{}, target, optimize);
    const checkpoint_mod = makeZigModule(
        b,
        "zig/checkpoint/checkpoint.zig",
        &.{.{ .name = "checker", .module = checker_mod }},
        target,
        optimize,
    );
    const recovery_block_mod = makeZigModule(
        b,
        "zig/recovery_block/recovery_block.zig",
        &.{
            .{ .name = "checker", .module = checker_mod },
            .{ .name = "checkpoint", .module = checkpoint_mod },
        },
        target,
        optimize,
    );
    const control_flow_mod = makeZigModule(
        b,
        "zig/control_flow/control_flow.zig",
        &.{},
        target,
        optimize,
    );

    addZigTest(b, tmr_mod, test_step);
    addZigTest(b, checker_mod, test_step);
    addZigTest(b, checkpoint_mod, test_step);
    addZigTest(b, recovery_block_mod, test_step);
    addZigTest(b, control_flow_mod, test_step);

    addCTest(
        b,
        "c-tmr-tests",
        "c/tmr/tmr_test.c",
        &.{ "c/common", "c/tmr" },
        target,
        optimize,
        test_step,
    );
    addCTest(
        b,
        "c-checker-tests",
        "c/checker/checker_test.c",
        &.{ "c/common", "c/checker" },
        target,
        optimize,
        test_step,
    );
    addCTest(
        b,
        "c-checkpoint-tests",
        "c/checkpoint/checkpoint_test.c",
        &.{ "c/common", "c/checker", "c/checkpoint" },
        target,
        optimize,
        test_step,
    );
    addCTest(
        b,
        "c-recovery-block-tests",
        "c/recovery_block/recovery_block_test.c",
        &.{ "c/common", "c/checker", "c/checkpoint", "c/recovery_block" },
        target,
        optimize,
        test_step,
    );
    addCTest(
        b,
        "c-control-flow-tests",
        "c/control_flow/control_flow_test.c",
        &.{ "c/common", "c/control_flow" },
        target,
        optimize,
        test_step,
    );

    const harness_step = b.step(
        "harness",
        "Build QEMU fault-injection harness firmware (all targets)",
    );
    const fuzz_harness_step = b.step(
        "fuzz-harness",
        "Build single-shot QEMU fuzz harness firmware (all targets)",
    );

    const mps2_an386 = b.resolveTargetQuery(.{
        .cpu_arch = .thumb,
        .cpu_model = .{ .explicit = &std.Target.arm.cpu.cortex_m4 },
        .os_tag = .freestanding,
        .abi = .eabi,
        .ofmt = .elf,
    });
    const virt_rv32 = b.resolveTargetQuery(.{
        .cpu_arch = .riscv32,
        .cpu_model = .{ .explicit = &std.Target.riscv.cpu.generic_rv32 },
        .os_tag = .freestanding,
        .abi = .eabi,
        .ofmt = .elf,
    });

    const profiles = [_]TargetProfile{
        .{
            .target = mps2_an386,
            .suffix = "m4",
            .startup = "harness/common/startup_mps2_an386.s",
            .linker = "harness/common/mps2_an386.ld",
            .entry = "Reset_Handler",
        },
        .{
            .target = virt_rv32,
            .suffix = "rv32",
            .startup = "harness/common/startup_virt_riscv32.s",
            .linker = "harness/common/virt_riscv32.ld",
            .entry = "_start",
        },
    };

    for (profiles) |profile| {
        addHarnessesForProfile(b, profile, optimize, harness_step, fuzz_harness_step);
    }
}

// addHarnessesForProfile emits the full e2e + fuzz harness set for one target.
// Zig modules bind their target at creation, so each profile gets its own module
// instances; ELF names get the profile suffix appended by the harness helpers.
fn addHarnessesForProfile(
    b: *std.Build,
    profile: TargetProfile,
    optimize: std.builtin.OptimizeMode,
    harness_step: *std.Build.Step,
    fuzz_harness_step: *std.Build.Step,
) void {
    const tgt = profile.target;

    // ---- C e2e harnesses ----
    addCHarness(b, profile, "tmr-harness-c", "harness/e2e/c/tmr_harness.c", &.{ "harness/common", "c/tmr" }, optimize, harness_step);
    addCHarness(b, profile, "checkpoint-harness-c", "harness/e2e/c/checkpoint_harness.c", &.{ "harness/common", "c/checker", "c/checkpoint" }, optimize, harness_step);
    addCHarness(b, profile, "recovery-block-harness-c", "harness/e2e/c/recovery_block_harness.c", &.{ "harness/common", "c/checker", "c/checkpoint", "c/recovery_block" }, optimize, harness_step);
    addCHarness(b, profile, "control-flow-harness-c", "harness/e2e/c/control_flow_harness.c", &.{ "harness/common", "c/control_flow" }, optimize, harness_step);
    addCHarness(b, profile, "combined-harness-c", "harness/e2e/c/combined_harness.c", &.{ "harness/common", "c/tmr", "c/checker", "c/checkpoint", "c/recovery_block", "c/control_flow" }, optimize, harness_step);
    addCHarness(b, profile, "baseline-harness-c", "harness/e2e/c/baseline_harness.c", &.{"harness/common"}, optimize, harness_step);

    // ---- C fuzz harnesses (extra include dir + fuzz_common.c) ----
    addCFuzzHarness(b, profile, "tmr-fuzz-harness-c", "harness/fuzz/c/tmr_fuzz_harness.c", &.{ "harness/fuzz/c", "harness/common", "c/tmr" }, optimize, fuzz_harness_step);
    addCFuzzHarness(b, profile, "checkpoint-fuzz-harness-c", "harness/fuzz/c/checkpoint_fuzz_harness.c", &.{ "harness/fuzz/c", "harness/common", "c/checker", "c/checkpoint" }, optimize, fuzz_harness_step);
    addCFuzzHarness(b, profile, "recovery-block-fuzz-harness-c", "harness/fuzz/c/recovery_block_fuzz_harness.c", &.{ "harness/fuzz/c", "harness/common", "c/checker", "c/checkpoint", "c/recovery_block" }, optimize, fuzz_harness_step);
    addCFuzzHarness(b, profile, "control-flow-fuzz-harness-c", "harness/fuzz/c/control_flow_fuzz_harness.c", &.{ "harness/fuzz/c", "harness/common", "c/control_flow" }, optimize, fuzz_harness_step);
    addCFuzzHarness(b, profile, "combined-fuzz-harness-c", "harness/fuzz/c/combined_fuzz_harness.c", &.{ "harness/fuzz/c", "harness/common", "c/tmr", "c/checker", "c/checkpoint", "c/recovery_block", "c/control_flow" }, optimize, fuzz_harness_step);
    addCFuzzHarness(b, profile, "baseline-fuzz-harness-c", "harness/fuzz/c/baseline_fuzz_harness.c", &.{ "harness/fuzz/c", "harness/common" }, optimize, fuzz_harness_step);

    // ---- per-target Zig modules ----
    const harness_abi = makeZigModule(b, "harness/common/harness_abi.zig", &.{}, tgt, optimize);
    const tmr = makeZigModule(b, "zig/tmr/tmr.zig", &.{}, tgt, optimize);
    const checker = makeZigModule(b, "zig/checker/checker.zig", &.{}, tgt, optimize);
    const checkpoint = makeZigModule(
        b,
        "zig/checkpoint/checkpoint.zig",
        &.{.{ .name = "checker", .module = checker }},
        tgt,
        optimize,
    );
    const recovery_block = makeZigModule(
        b,
        "zig/recovery_block/recovery_block.zig",
        &.{
            .{ .name = "checker", .module = checker },
            .{ .name = "checkpoint", .module = checkpoint },
        },
        tgt,
        optimize,
    );
    const control_flow = makeZigModule(b, "zig/control_flow/control_flow.zig", &.{}, tgt, optimize);

    // ---- Zig e2e harnesses ----
    addZigHarness(b, profile, "tmr-harness-zig", "harness/e2e/zig/tmr_harness.zig", &.{
        .{ .name = "tmr", .module = tmr },
        .{ .name = "abi", .module = harness_abi },
    }, optimize, harness_step);
    addZigHarness(b, profile, "checkpoint-harness-zig", "harness/e2e/zig/checkpoint_harness.zig", &.{
        .{ .name = "checker", .module = checker },
        .{ .name = "checkpoint", .module = checkpoint },
        .{ .name = "abi", .module = harness_abi },
    }, optimize, harness_step);
    addZigHarness(b, profile, "recovery-block-harness-zig", "harness/e2e/zig/recovery_block_harness.zig", &.{
        .{ .name = "checker", .module = checker },
        .{ .name = "checkpoint", .module = checkpoint },
        .{ .name = "recovery_block", .module = recovery_block },
        .{ .name = "abi", .module = harness_abi },
    }, optimize, harness_step);
    addZigHarness(b, profile, "control-flow-harness-zig", "harness/e2e/zig/control_flow_harness.zig", &.{
        .{ .name = "control_flow", .module = control_flow },
        .{ .name = "abi", .module = harness_abi },
    }, optimize, harness_step);
    addZigHarness(b, profile, "combined-harness-zig", "harness/e2e/zig/combined_harness.zig", &.{
        .{ .name = "tmr", .module = tmr },
        .{ .name = "checker", .module = checker },
        .{ .name = "checkpoint", .module = checkpoint },
        .{ .name = "recovery_block", .module = recovery_block },
        .{ .name = "control_flow", .module = control_flow },
        .{ .name = "abi", .module = harness_abi },
    }, optimize, harness_step);
    addZigHarness(b, profile, "baseline-harness-zig", "harness/e2e/zig/baseline_harness.zig", &.{
        .{ .name = "abi", .module = harness_abi },
    }, optimize, harness_step);

    // ---- Zig fuzz harnesses ----
    addZigHarness(b, profile, "tmr-fuzz-harness-zig", "harness/fuzz/zig/tmr_fuzz_harness.zig", &.{
        .{ .name = "tmr", .module = tmr },
    }, optimize, fuzz_harness_step);
    addZigHarness(b, profile, "checkpoint-fuzz-harness-zig", "harness/fuzz/zig/checkpoint_fuzz_harness.zig", &.{
        .{ .name = "checker", .module = checker },
        .{ .name = "checkpoint", .module = checkpoint },
    }, optimize, fuzz_harness_step);
    addZigHarness(b, profile, "recovery-block-fuzz-harness-zig", "harness/fuzz/zig/recovery_block_fuzz_harness.zig", &.{
        .{ .name = "checker", .module = checker },
        .{ .name = "checkpoint", .module = checkpoint },
        .{ .name = "recovery_block", .module = recovery_block },
    }, optimize, fuzz_harness_step);
    addZigHarness(b, profile, "control-flow-fuzz-harness-zig", "harness/fuzz/zig/control_flow_fuzz_harness.zig", &.{
        .{ .name = "control_flow", .module = control_flow },
    }, optimize, fuzz_harness_step);
    addZigHarness(b, profile, "combined-fuzz-harness-zig", "harness/fuzz/zig/combined_fuzz_harness.zig", &.{
        .{ .name = "tmr", .module = tmr },
        .{ .name = "checker", .module = checker },
        .{ .name = "checkpoint", .module = checkpoint },
        .{ .name = "recovery_block", .module = recovery_block },
        .{ .name = "control_flow", .module = control_flow },
    }, optimize, fuzz_harness_step);
    addZigHarness(b, profile, "baseline-fuzz-harness-zig", "harness/fuzz/zig/baseline_fuzz_harness.zig", &.{}, optimize, fuzz_harness_step);
}

fn makeZigModule(
    b: *std.Build,
    root_path: []const u8,
    imports: []const Import,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
) *std.Build.Module {
    const mod = b.createModule(.{
        .root_source_file = b.path(root_path),
        .target = target,
        .optimize = optimize,
    });
    for (imports) |imp| mod.addImport(imp.name, imp.module);
    return mod;
}

fn addZigTest(b: *std.Build, mod: *std.Build.Module, test_step: *std.Build.Step) void {
    const tests = b.addTest(.{ .root_module = mod });
    const run = b.addRunArtifact(tests);
    test_step.dependOn(&run.step);
}

fn addCTest(
    b: *std.Build,
    name: []const u8,
    source_path: []const u8,
    include_paths: []const []const u8,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    test_step: *std.Build.Step,
) void {
    const mod = b.createModule(.{
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    for (include_paths) |inc| mod.addIncludePath(b.path(inc));
    mod.addCSourceFile(.{
        .file = b.path(source_path),
        .flags = &.{ "-std=c11", "-Wall", "-Wextra" },
    });
    const exe = b.addExecutable(.{ .name = name, .root_module = mod });
    const run = b.addRunArtifact(exe);
    test_step.dependOn(&run.step);
}

fn addCHarness(
    b: *std.Build,
    profile: TargetProfile,
    name_base: []const u8,
    source_path: []const u8,
    include_paths: []const []const u8,
    optimize: std.builtin.OptimizeMode,
    harness_step: *std.Build.Step,
) void {
    const mod = b.createModule(.{
        .target = profile.target,
        .optimize = optimize,
    });
    for (include_paths) |inc| mod.addIncludePath(b.path(inc));
    mod.addAssemblyFile(b.path(profile.startup));
    mod.addCSourceFile(.{
        .file = b.path(source_path),
        .flags = &.{ "-std=c11", "-Wall", "-Wextra", "-ffreestanding", "-fno-builtin" },
    });
    installFirmware(b, profile, mod, name_base, harness_step);
}

fn addCFuzzHarness(
    b: *std.Build,
    profile: TargetProfile,
    name_base: []const u8,
    source_path: []const u8,
    include_paths: []const []const u8,
    optimize: std.builtin.OptimizeMode,
    harness_step: *std.Build.Step,
) void {
    const mod = b.createModule(.{
        .target = profile.target,
        .optimize = optimize,
    });
    for (include_paths) |inc| mod.addIncludePath(b.path(inc));
    mod.addAssemblyFile(b.path(profile.startup));
    const c_flags = &.{ "-std=c11", "-Wall", "-Wextra", "-ffreestanding", "-fno-builtin" };
    mod.addCSourceFile(.{ .file = b.path(source_path), .flags = c_flags });
    mod.addCSourceFile(.{ .file = b.path("harness/fuzz/c/fuzz_common.c"), .flags = c_flags });
    installFirmware(b, profile, mod, name_base, harness_step);
}

fn addZigHarness(
    b: *std.Build,
    profile: TargetProfile,
    name_base: []const u8,
    root_source_path: []const u8,
    imports: []const Import,
    optimize: std.builtin.OptimizeMode,
    harness_step: *std.Build.Step,
) void {
    const mod = b.createModule(.{
        .root_source_file = b.path(root_source_path),
        .target = profile.target,
        .optimize = optimize,
    });
    for (imports) |imp| mod.addImport(imp.name, imp.module);
    mod.addAssemblyFile(b.path(profile.startup));
    installFirmware(b, profile, mod, name_base, harness_step);
}

// installFirmware builds the executable for `name_base-<suffix>`, applies the
// profile's entry symbol and linker script, and installs it as a .elf into
// zig-out/harness/.
fn installFirmware(
    b: *std.Build,
    profile: TargetProfile,
    mod: *std.Build.Module,
    name_base: []const u8,
    harness_step: *std.Build.Step,
) void {
    const name = b.fmt("{s}-{s}", .{ name_base, profile.suffix });
    const exe = b.addExecutable(.{ .name = name, .root_module = mod });
    exe.entry = .{ .symbol_name = profile.entry };
    exe.link_gc_sections = true;
    exe.setLinkerScript(b.path(profile.linker));
    const install = b.addInstallArtifact(exe, .{
        .dest_dir = .{ .override = .{ .custom = "harness" } },
        .dest_sub_path = b.fmt("{s}.elf", .{name}),
    });
    harness_step.dependOn(&install.step);
}

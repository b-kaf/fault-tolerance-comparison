const std = @import("std");

const Import = struct {
    name: []const u8,
    module: *std.Build.Module,
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

    const mps2_an386 = b.resolveTargetQuery(.{
        .cpu_arch = .thumb,
        .cpu_model = .{ .explicit = &std.Target.arm.cpu.cortex_m4 },
        .os_tag = .freestanding,
        .abi = .eabi,
        .ofmt = .elf,
    });

    const harness_step = b.step(
        "harness",
        "Build QEMU mps2-an386 Cortex-M4 fault-injection harness firmware",
    );

    addCortexM4CHarness(
        b,
        "tmr-harness-c-m4",
        "harness/c/tmr_harness.c",
        &.{ "harness/common", "c/tmr" },
        "tmr-harness-c-m4.elf",
        mps2_an386,
        optimize,
        harness_step,
    );
    addCortexM4CHarness(
        b,
        "checkpoint-harness-c-m4",
        "harness/c/checkpoint_harness.c",
        &.{ "harness/common", "c/checker", "c/checkpoint" },
        "checkpoint-harness-c-m4.elf",
        mps2_an386,
        optimize,
        harness_step,
    );
    addCortexM4CHarness(
        b,
        "recovery-block-harness-c-m4",
        "harness/c/recovery_block_harness.c",
        &.{ "harness/common", "c/checker", "c/checkpoint", "c/recovery_block" },
        "recovery-block-harness-c-m4.elf",
        mps2_an386,
        optimize,
        harness_step,
    );
    addCortexM4CHarness(
        b,
        "control-flow-harness-c-m4",
        "harness/c/control_flow_harness.c",
        &.{ "harness/common", "c/control_flow" },
        "control-flow-harness-c-m4.elf",
        mps2_an386,
        optimize,
        harness_step,
    );

    const harness_abi_m4 = makeZigModule(
        b,
        "harness/common/harness_abi.zig",
        &.{},
        mps2_an386,
        optimize,
    );
    const tmr_m4 = makeZigModule(b, "zig/tmr/tmr.zig", &.{}, mps2_an386, optimize);
    const checker_m4 = makeZigModule(b, "zig/checker/checker.zig", &.{}, mps2_an386, optimize);
    const checkpoint_m4 = makeZigModule(
        b,
        "zig/checkpoint/checkpoint.zig",
        &.{.{ .name = "checker", .module = checker_m4 }},
        mps2_an386,
        optimize,
    );
    const recovery_block_m4 = makeZigModule(
        b,
        "zig/recovery_block/recovery_block.zig",
        &.{
            .{ .name = "checker", .module = checker_m4 },
            .{ .name = "checkpoint", .module = checkpoint_m4 },
        },
        mps2_an386,
        optimize,
    );
    const control_flow_m4 = makeZigModule(
        b,
        "zig/control_flow/control_flow.zig",
        &.{},
        mps2_an386,
        optimize,
    );

    addCortexM4ZigHarness(
        b,
        "tmr-harness-zig-m4",
        "harness/zig/tmr_harness.zig",
        &.{
            .{ .name = "tmr", .module = tmr_m4 },
            .{ .name = "abi", .module = harness_abi_m4 },
        },
        "tmr-harness-zig-m4.elf",
        mps2_an386,
        optimize,
        harness_step,
    );
    addCortexM4ZigHarness(
        b,
        "checkpoint-harness-zig-m4",
        "harness/zig/checkpoint_harness.zig",
        &.{
            .{ .name = "checker", .module = checker_m4 },
            .{ .name = "checkpoint", .module = checkpoint_m4 },
            .{ .name = "abi", .module = harness_abi_m4 },
        },
        "checkpoint-harness-zig-m4.elf",
        mps2_an386,
        optimize,
        harness_step,
    );
    addCortexM4ZigHarness(
        b,
        "recovery-block-harness-zig-m4",
        "harness/zig/recovery_block_harness.zig",
        &.{
            .{ .name = "checker", .module = checker_m4 },
            .{ .name = "checkpoint", .module = checkpoint_m4 },
            .{ .name = "recovery_block", .module = recovery_block_m4 },
            .{ .name = "abi", .module = harness_abi_m4 },
        },
        "recovery-block-harness-zig-m4.elf",
        mps2_an386,
        optimize,
        harness_step,
    );
    addCortexM4ZigHarness(
        b,
        "control-flow-harness-zig-m4",
        "harness/zig/control_flow_harness.zig",
        &.{
            .{ .name = "control_flow", .module = control_flow_m4 },
            .{ .name = "abi", .module = harness_abi_m4 },
        },
        "control-flow-harness-zig-m4.elf",
        mps2_an386,
        optimize,
        harness_step,
    );
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

fn addCortexM4CHarness(
    b: *std.Build,
    name: []const u8,
    source_path: []const u8,
    include_paths: []const []const u8,
    install_sub_path: []const u8,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    harness_step: *std.Build.Step,
) void {
    const mod = b.createModule(.{
        .target = target,
        .optimize = optimize,
    });
    for (include_paths) |inc| mod.addIncludePath(b.path(inc));
    mod.addAssemblyFile(b.path("harness/common/startup_mps2_an386.s"));
    mod.addCSourceFile(.{
        .file = b.path(source_path),
        .flags = &.{ "-std=c11", "-Wall", "-Wextra", "-ffreestanding", "-fno-builtin" },
    });
    const exe = b.addExecutable(.{ .name = name, .root_module = mod });
    exe.entry = .{ .symbol_name = "Reset_Handler" };
    exe.link_gc_sections = true;
    exe.setLinkerScript(b.path("harness/common/mps2_an386.ld"));
    installHarness(b, exe, install_sub_path, harness_step);
}

fn addCortexM4ZigHarness(
    b: *std.Build,
    name: []const u8,
    root_source_path: []const u8,
    imports: []const Import,
    install_sub_path: []const u8,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    harness_step: *std.Build.Step,
) void {
    const mod = b.createModule(.{
        .root_source_file = b.path(root_source_path),
        .target = target,
        .optimize = optimize,
    });
    for (imports) |imp| mod.addImport(imp.name, imp.module);
    mod.addAssemblyFile(b.path("harness/common/startup_mps2_an386.s"));
    const exe = b.addExecutable(.{ .name = name, .root_module = mod });
    exe.entry = .{ .symbol_name = "Reset_Handler" };
    exe.link_gc_sections = true;
    exe.setLinkerScript(b.path("harness/common/mps2_an386.ld"));
    installHarness(b, exe, install_sub_path, harness_step);
}

fn installHarness(
    b: *std.Build,
    exe: *std.Build.Step.Compile,
    sub_path: []const u8,
    harness_step: *std.Build.Step,
) void {
    const install = b.addInstallArtifact(exe, .{
        .dest_dir = .{ .override = .{ .custom = "harness" } },
        .dest_sub_path = sub_path,
    });
    harness_step.dependOn(&install.step);
}

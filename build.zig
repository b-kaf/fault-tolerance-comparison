const std = @import("std");

// Although this function looks imperative, it does not perform the build
// directly and instead it mutates the build graph (`b`) that will be then
// executed by an external runner. The functions in `std.Build` implement a DSL
// for defining build steps and express dependencies between them, allowing the
// build runner to parallelize the build automatically (and the cache system to
// know when a step doesn't need to be re-run).
pub fn build(b: *std.Build) void {
    // Standard target options allow the person running `zig build` to choose
    // what target to build for. Here we do not override the defaults, which
    // means any target is allowed, and the default is native. Other options
    // for restricting supported target set are available.
    const target = b.standardTargetOptions(.{});
    // Standard optimization options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall. Here we do not
    // set a preferred release mode, allowing the user to decide how to optimize.
    const optimize = b.standardOptimizeOption(.{});
    // It's also possible to define more custom flags to toggle optional features
    // of this build script using `b.option()`. All defined flags (including
    // target and optimize options) will be listed when running `zig build --help`
    // in this directory.
    const tmr_mod = b.createModule(.{
        .root_source_file = b.path("zig/tmr/tmr.zig"),
        .target = target,
        .optimize = optimize,
    });

    const tmr_tests = b.addTest(.{
        .root_module = tmr_mod,
    });

    const run_tmr = b.addRunArtifact(tmr_tests);

    const checker_mod = b.createModule(.{
        .root_source_file = b.path("zig/checker/checker.zig"),
        .target = target,
        .optimize = optimize,
    });

    const checker_tests = b.addTest(.{
        .root_module = checker_mod,
    });

    const run_checker = b.addRunArtifact(checker_tests);

    const c_tmr_mod = b.createModule(.{
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    c_tmr_mod.addIncludePath(b.path("c/common"));
    c_tmr_mod.addIncludePath(b.path("c/tmr"));
    c_tmr_mod.addCSourceFile(.{
        .file = b.path("c/tmr/tmr_test.c"),
        .flags = &.{
            "-std=c11",
            "-Wall",
            "-Wextra",
        },
    });

    const c_tmr_tests = b.addExecutable(.{
        .name = "c-tmr-tests",
        .root_module = c_tmr_mod,
    });

    const run_c_tmr = b.addRunArtifact(c_tmr_tests);

    const c_checker_mod = b.createModule(.{
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    c_checker_mod.addIncludePath(b.path("c/common"));
    c_checker_mod.addIncludePath(b.path("c/checker"));
    c_checker_mod.addCSourceFile(.{
        .file = b.path("c/checker/checker_test.c"),
        .flags = &.{
            "-std=c11",
            "-Wall",
            "-Wextra",
        },
    });

    const c_checker_tests = b.addExecutable(.{
        .name = "c-checker-tests",
        .root_module = c_checker_mod,
    });

    const run_c_checker = b.addRunArtifact(c_checker_tests);

    const test_step = b.step("test", "Run all tests");

    test_step.dependOn(&run_tmr.step);
    test_step.dependOn(&run_checker.step);
    test_step.dependOn(&run_c_tmr.step);
    test_step.dependOn(&run_c_checker.step);

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

    const harness_c_mod = b.createModule(.{
        .target = mps2_an386,
        .optimize = optimize,
    });
    harness_c_mod.addIncludePath(b.path("harness/common"));
    harness_c_mod.addIncludePath(b.path("c/tmr"));
    harness_c_mod.addAssemblyFile(b.path("harness/common/startup_mps2_an386.s"));
    harness_c_mod.addCSourceFile(.{
        .file = b.path("harness/c/tmr_harness.c"),
        .flags = &.{
            "-std=c11",
            "-Wall",
            "-Wextra",
            "-ffreestanding",
            "-fno-builtin",
        },
    });

    const harness_c = b.addExecutable(.{
        .name = "tmr-harness-c-m4",
        .root_module = harness_c_mod,
    });
    harness_c.entry = .{ .symbol_name = "Reset_Handler" };
    harness_c.link_gc_sections = false;
    harness_c.setLinkerScript(b.path("harness/common/mps2_an386.ld"));

    const tmr_import_mod = b.createModule(.{
        .root_source_file = b.path("zig/tmr/tmr.zig"),
        .target = mps2_an386,
        .optimize = optimize,
    });
    const harness_zig_mod = b.createModule(.{
        .root_source_file = b.path("harness/zig/tmr_harness.zig"),
        .target = mps2_an386,
        .optimize = optimize,
    });
    harness_zig_mod.addImport("tmr", tmr_import_mod);
    harness_zig_mod.addAssemblyFile(b.path("harness/common/startup_mps2_an386.s"));

    const harness_zig = b.addExecutable(.{
        .name = "tmr-harness-zig-m4",
        .root_module = harness_zig_mod,
    });
    harness_zig.entry = .{ .symbol_name = "Reset_Handler" };
    harness_zig.link_gc_sections = false;
    harness_zig.setLinkerScript(b.path("harness/common/mps2_an386.ld"));

    const install_harness_c = b.addInstallArtifact(harness_c, .{
        .dest_dir = .{ .override = .{ .custom = "harness" } },
        .dest_sub_path = "tmr-harness-c-m4.elf",
    });
    const install_harness_zig = b.addInstallArtifact(harness_zig, .{
        .dest_dir = .{ .override = .{ .custom = "harness" } },
        .dest_sub_path = "tmr-harness-zig-m4.elf",
    });

    harness_step.dependOn(&install_harness_c.step);
    harness_step.dependOn(&install_harness_zig.step);
}

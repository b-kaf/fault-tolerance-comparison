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

    const c_tmr_mod = b.createModule(.{
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
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

    const test_step = b.step("test", "Run all tests");

    test_step.dependOn(&run_tmr.step);
    test_step.dependOn(&run_c_tmr.step);
}

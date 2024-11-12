const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{ .preferred_optimize_mode = std.builtin.OptimizeMode.ReleaseFast });

    const lib = b.addStaticLibrary(.{
        .name = "ulid",
        .root_source_file = b.path("src/ulid.zig"),
        .target = target,
        .optimize = optimize,
    });

    b.installArtifact(lib);

    const exe = b.addExecutable(.{
        .name = "basic",
        .root_source_file = b.path("examples/basic/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    const ulid_mod = b.addModule("ulid", .{
        .root_source_file = .{ .src_path = .{ .owner = b, .sub_path = "src/ulid.zig" } },
    });
    exe.root_module.addImport("ulid", ulid_mod);
    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);

    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    const bench = b.addExecutable(.{
        .name = "bench",
        .root_source_file = b.path("bench/bench.zig"),
        .target = target,
        .optimize = optimize,
    });

    const opts = .{ .target = target, .optimize = optimize };
    const zbench_module = b.dependency("zbench", opts).module("zbench");

    bench.root_module.addImport("zbench", zbench_module);
    bench.root_module.addImport("ulid", ulid_mod);
    b.installArtifact(bench);

    const bench_cmd = b.addRunArtifact(bench);

    bench_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        bench_cmd.addArgs(args);
    }

    const bench_step = b.step("benchmark", "Run the benchmark");
    bench_step.dependOn(&bench_cmd.step);

    const lib_unit_tests = b.addTest(.{
        .root_source_file = b.path("src/ulid.zig"),
        .target = target,
        .optimize = optimize,
    });

    const run_lib_unit_tests = b.addRunArtifact(lib_unit_tests);

    const exe_unit_tests = b.addTest(.{
        .root_source_file = b.path("src/ulid.zig"),
        .target = target,
        .optimize = optimize,
    });

    const run_exe_unit_tests = b.addRunArtifact(exe_unit_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_lib_unit_tests.step);
    test_step.dependOn(&run_exe_unit_tests.step);
}

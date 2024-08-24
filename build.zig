const std = @import("std");

fn commonExeConfig(b: *std.Build, exe: *std.Build.Step.Compile, bazel_obj_name: [] const u8) !void {

    const clap = b.dependency("clap", .{});
    exe.root_module.addImport("clap", clap.module("clap"));

    // Link against C libraries
    exe.linkLibC();
    exe.linkSystemLibrary("grpc");

    // Explicitly link against libatomic
    exe.addLibraryPath(.{ .cwd_relative = "/lib/x86_64-linux-gnu"});
    exe.addObjectFile(.{ .cwd_relative = "/lib/x86_64-linux-gnu/libatomic.so.1"});
    exe.linkLibCpp();
    exe.addIncludePath(.{ .cwd_relative = "src/helloworld"});
    exe.addIncludePath(.{ .cwd_relative = "bazel-bin"});
    exe.addIncludePath(.{ .cwd_relative = "bazel-bin/src/protos"});

    var buf: [200]u8 = undefined;
    const bufs = buf[0..];
    // hack: use a `cc_binary` linked with linkstatic and linkshared to build a self-contained .so:
    const obj_file = try std.fmt.bufPrint(bufs, "bazel-bin/src/helloworld/lib{s}.so", .{bazel_obj_name});
    exe.addObjectFile(.{ .cwd_relative = obj_file});
}

pub fn build(b: *std.Build) void {
    // Standard target options allows the person running `zig build` to choose
    // what target to build for. Here we do not override the defaults, which
    // means any target is allowed, and the default is native. Other options
    // for restricting supported target set are available.
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Greeter server
    const greeter_server = b.addExecutable(.{
        .name = "greeter_server",
        .root_source_file = .{ .cwd_relative = "src/greeter_server.zig" },
        .target = target,
	.optimize = optimize,
    });

    commonExeConfig(b, greeter_server, "greeter_server") catch |err| {
        std.log.err("build error: {!}", .{err});
    };
    b.installArtifact(greeter_server);

    const run_greeter_server_cmd = b.addRunArtifact(greeter_server);
    run_greeter_server_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_greeter_server_cmd.addArgs(args);
    }

    const run_greeter_server_step = b.step("run_greeter_server", "Run the greeter_server app");
    run_greeter_server_step.dependOn(&run_greeter_server_cmd.step);

    const greeter_server_tests = b.addTest(.{
        .root_source_file = .{ .cwd_relative = "src/greeter_server.zig" },
        .target = target,
    });

    const test_greeter_server_step = b.step("test_greeter_server", "Run unit tests");
    test_greeter_server_step.dependOn(&greeter_server_tests.step);

    // Greeter client
    const greeter_client = b.addExecutable(.{
        .name = "greeter_client",
        .root_source_file = .{ .cwd_relative = "src/greeter_client.zig" },
        .target = target,
        .optimize = optimize,
    });

    commonExeConfig(b, greeter_client, "greeter_client") catch |err| {
        std.log.err("build error: {!}", .{err});
    };
    b.installArtifact(greeter_client);

    const run_greeter_client_cmd = b.addRunArtifact(greeter_client);
    run_greeter_client_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_greeter_client_cmd.addArgs(args);
    }

    const run_greeter_client_step = b.step("run_greeter_client", "Run the greeter_client app");
    run_greeter_client_step.dependOn(&run_greeter_client_cmd.step);

    const greeter_client_tests = b.addTest(.{
        .root_source_file = .{ .cwd_relative = "src/greeter_client.zig" },  
        .target = target,
    });

    const greeter_client_test_step = b.step("test_greeter_client", "Run unit tests");
    greeter_client_test_step.dependOn(&greeter_client_tests.step);
}

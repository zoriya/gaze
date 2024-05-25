const std = @import("std");

const Scanner = @import("zig-wayland").Scanner;

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const scanner = Scanner.create(b, .{});
    scanner.addSystemProtocol("stable/xdg-shell/xdg-shell.xml");

    // These must be manually kept in sync with the versions wlroots supports
    // until wlroots gives the option to request a specific version.
    scanner.generate("wl_compositor", 4);
    scanner.generate("wl_subcompositor", 1);
    scanner.generate("wl_shm", 1);
    scanner.generate("wl_output", 4);
    scanner.generate("wl_seat", 7);
    scanner.generate("wl_data_device_manager", 3);
    scanner.generate("xdg_wm_base", 2);

    const wayland = b.createModule(.{ .root_source_file = scanner.result });
    const xkbcommon = b.dependency("zig-xkbcommon", .{}).module("xkbcommon");
    const pixman = b.dependency("zig-pixman", .{}).module("pixman");
    const wlroots = b.dependency("zig-wlroots", .{}).module("wlroots");

    wlroots.addImport("wayland", wayland);
    wlroots.addImport("xkbcommon", xkbcommon);
    wlroots.addImport("pixman", pixman);

    wlroots.resolved_target = target;
    wlroots.linkSystemLibrary("wlroots", .{});

    const ziglua = b.dependency("ziglua", .{
        .target = target,
        .optimize = optimize,
    });

    const gaze = b.addExecutable(.{
        .name = "gaze",
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });

    gaze.linkLibC();

    gaze.root_module.addImport("wayland", wayland);
    gaze.root_module.addImport("xkbcommon", xkbcommon);
    gaze.root_module.addImport("wlroots", wlroots);
    gaze.root_module.addImport("ziglua", ziglua.module("ziglua"));

    gaze.linkSystemLibrary("wayland-server");
    gaze.linkSystemLibrary("xkbcommon");
    gaze.linkSystemLibrary("pixman-1");

    // TODO: remove when https://github.com/ziglang/zig/issues/131 is implemented
    scanner.addCSource(gaze);

    b.installArtifact(gaze);
}

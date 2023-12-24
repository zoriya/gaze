const std = @import("std");
const gpa = std.heap.c_allocator;

const serv = @import("server.zig");

pub fn exec(server: *serv.Server, cmd: [:0]const u8) !void {
    var child = std.ChildProcess.init(&[_][]const u8{ "/bin/sh", "-c", cmd }, gpa);
    var env_map = try std.process.getEnvMap(gpa);
    defer env_map.deinit();
    try env_map.put("WAYLAND_DISPLAY", server.socket);
    child.env_map = &env_map;
    try child.spawn();
}

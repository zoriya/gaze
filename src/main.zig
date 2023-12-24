const std = @import("std");
const builtin = @import("builtin");

const wl = @import("wayland").server.wl;
const wlr = @import("wlroots");

const Server = @import("server.zig").Server;
const commands = @import("commands.zig");

pub fn main() anyerror!void {
    wlr.log.init(.debug, wlr_print);

    var server: Server = undefined;
    try Server.init(&server);
    defer server.destroy();

    // exec the first arg for now to test the compositor.
    if (std.os.argv.len > 1) {
        try commands.exec(&server, std.mem.span(std.os.argv[1]));
    }

    try server.backend.start();
    std.log.info("Running compositor on WAYLAND_DISPLAY={s}", .{server.socket});
    server.wl_server.run();
}

pub const log_level: std.log.Level = switch (builtin.mode) {
    .Debug => .debug,
    .ReleaseSafe, .ReleaseFast, .ReleaseSmall => .info,
};

pub fn log(
    comptime level: std.log.Level,
    comptime scope: @TypeOf(.EnumLiteral),
    comptime format: []const u8,
    args: anytype,
) void {
    if (@intFromEnum(level) > @intFromEnum(log_level)) return;

    const scope_prefix = if (scope == .default) ": " else "(" ++ @tagName(scope) ++ "): ";
    const stderr = std.io.getStdErr().writer();
    stderr.print(level.asText() ++ scope_prefix ++ format ++ "\n", args) catch {};
}

extern fn vsnprintf(buf: [*c]u8, size: usize, fmt: [*:0]const u8, args: *std.builtin.VaList) callconv(.C) c_int;
fn wlr_print(importance: wlr.log.Importance, fmt: [*:0]const u8, args: *std.builtin.VaList) callconv(.C) void {
    const buf_len = 2048;
    var buf: [buf_len]u8 = undefined;
    const ret = vsnprintf(&buf, buf_len, fmt, args);
    if (ret < 0) return;
    const ulen: usize = @intCast(ret);
    const len: usize = @min(buf_len, ulen);
    switch (importance) {
        .err => log(.err, .wlroots, "{s}", .{buf[0..len]}),
        .info => log(.info, .wlroots, "{s}", .{buf[0..len]}),
        .debug => log(.debug, .wlroots, "{s}", .{buf[0..len]}),
        .silent, .last => unreachable,
    }
}

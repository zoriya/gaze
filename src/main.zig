const std = @import("std");

const wl = @import("wayland").server.wl;
const wlr = @import("wlroots");

const Server = @import("server.zig").Server;

pub fn main() anyerror!void {
    wlr.log.init(.debug, null);

    var server: Server = undefined;
    try Server.init(&server);
    defer server.destroy();

    var buf: [11]u8 = undefined;
    const socket = try server.wl_server.addSocketAuto(&buf);

    try server.backend.start();
    std.log.info("Running compositor on WAYLAND_DISPLAY={s}", .{socket});
    server.wl_server.run();
}

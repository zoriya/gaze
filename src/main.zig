const std = @import("std");

const wl = @import("wayland").server.wl;
const wlr = @import("wlroots");

const Server = @import("server.zig").Server;

pub fn main() anyerror!void {
    wlr.log.init(.debug, null);

    var server: Server = undefined;
    try Server.init(&server);
    defer server.destroy();
}

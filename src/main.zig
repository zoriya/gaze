const std = @import("std");

const wl = @import("wayland").server.wl;
const wlr = @import("wlroots");

pub fn main() anyerror!void {
    wlr.log.init(.debug, null);
}

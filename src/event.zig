const std = @import("std");
const wl = @import("wayland").server.wl;
const wlr = @import("wlroots");

const serv = @import("server/server.zig");

fn Event(comptime name: []const u8, comptime T: type) type {
    return struct {
        wl_listener: wl.Listener(*T) = wl.Listener(*T).init(call),
        listener: ?*const fn (server: *serv.Server, data: *T) void = null,

        fn call(listener: *wl.Listener(*T), data: *T) void {
            const self: *Event(name, T) = @fieldParentPtr("wl_listener", listener);
            const events: *Events = @fieldParentPtr(name, self);
            const server = events.server;
            std.log.debug("calling event {s}", .{name});
            if (self.listener) |l| {
                l(server, data);
            }
            // TODO: call the lua event listener
        }
    };
}

pub const Events = struct {
    server: *serv.Server,

    new_monitor: Event("new_monitor", wlr.Output) = .{},
    new_input: Event("new_input", wlr.InputDevice) = .{},
    new_xdg_surface: Event("new_xdg_surface", wlr.XdgSurface) = .{},

    pub fn init(self: *Events, server: *serv.Server) void {
        self.* = .{ .server = server };
        server.backend.events.new_output.add(&self.new_monitor.wl_listener);
        server.backend.events.new_input.add(&self.new_input.wl_listener);
        server.xdg_shell.events.new_surface.add(&self.new_xdg_surface.wl_listener);
    }
};

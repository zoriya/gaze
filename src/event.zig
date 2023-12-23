const std = @import("std");
const wl = @import("wayland").server.wl;
const wlr = @import("wlroots");

const serv = @import("server.zig");

fn Event(comptime name: []const u8, comptime T: type) type {
    return struct {
        wl_listener: wl.Listener(*T) = wl.Listener(*T).init(call),
        listener: ?*const fn (server: *serv.Server, data: *T) void = null,

        fn call(listener: *wl.Listener(*T), data: *T) void {
            const self = @fieldParentPtr(Event(name, T), "wl_listener", listener);
            const server = @fieldParentPtr(Events, name, self).server;
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

    new_output: Event("new_output", wlr.Output) = .{},

    pub fn init(self: *Events, server: *serv.Server) void {
        self.* = .{ .server = server };
        server.backend.events.new_output.add(&self.new_output.wl_listener);
    }
};
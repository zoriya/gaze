const std = @import("std");
const wl = @import("wayland").server.wl;
const wlr = @import("wlroots");

const serv = @import("server.zig");

pub fn Event(comptime name: [*:0]const u8, comptime T: type) type {
    return struct {
        wl_listener: wl.Listener(*T) = wl.Listener(*T).init(call),
        listener: ?*const fn (data: *T) void,

        fn call(listener: *wl.Listener(*T), data: *T) void {
            const self = @fieldParentPtr(Event(name, T), "wl_listener", listener);
            std.log.debug("calling event {}", .{name});
            if (self.listener) |l| {
                l(data);
            }
            // TODO: call the lua event listener
        }
    };
}

pub const Events = struct {
    new_output: Event("new_output", wlr.Output),

    pub fn init(self: Events, server: serv.Server) void {
        server.backend.events.new_output.add(&self.new_output.wl_listener);
    }
};

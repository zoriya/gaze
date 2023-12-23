const std = @import("std");

const wl = @import("wayland").server.wl;
const wlr = @import("wlroots");

const events = @import("event.zig");

pub const Server = struct {
    wl_server: *wl.Server,
    backend: *wlr.Backend,
    renderer: *wlr.Renderer,
    allocator: *wlr.Allocator,

    output_layout: *wlr.OutputLayout,

    events: events.Events,

    pub fn init(self: *Server) !void {
        const wl_server = try wl.Server.create();
        const backend = try wlr.Backend.autocreate(wl_server, null);
        const renderer = try wlr.Renderer.autocreate(backend);

        self.* = Server{
            .wl_server = wl_server,
            .backend = backend,
            .renderer = renderer,
            .allocator = try wlr.Allocator.autocreate(backend, renderer),
            .output_layout = try wlr.OutputLayout.create(),
            .events = undefined,
        };
        errdefer self.destroy();

        try self.renderer.initServer(self.wl_server);
        _ = try wlr.Compositor.create(self.wl_server, 6, self.renderer);
        _ = try wlr.Subcompositor.create(self.wl_server);
        _ = try wlr.DataDeviceManager.create(self.wl_server);

        self.events.init(*self);
        self.attach_events();
    }

    fn attach_events(self: Server) void {
        _ = self;
    }

    pub fn destroy(self: Server) void {
        self.wl_server.destroyClients();
        self.wl_server.destroy();
    }
};

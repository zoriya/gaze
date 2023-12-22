const std = @import("std");

const wl = @import("wayland").server.wl;
const wlr = @import("wlroots");

pub const Server = struct {
    wl_server: *wl.Server,
    backend:  *wlr.Backend,
    renderer: *wlr.Renderer,
    allocator: *wlr.Allocator,

    output_layout: *wlr.OutputLayout,

    pub fn create() !Server {
        const wl_server = try wl.Server.create();
        const backend = try wlr.Backend.autocreate(wl_server, null);
        const renderer = try wlr.Renderer.autocreate(backend);

        const self = Server {
            .wl_server = wl_server,
            .backend = backend,
            .renderer = renderer,
            .allocator = try wlr.Allocator.autocreate(backend, renderer),
            .output_layout = try wlr.OutputLayout.create(),
        };
        errdefer self.destroy();

        try self.renderer.initServer(self.wl_server);
        _ = try wlr.Compositor.create(self.wl_server, 6, self.renderer);
        _ = try wlr.Subcompositor.create(self.wl_server);
        _ = try wlr.DataDeviceManager.create(self.wl_server);

        return self;
    }

    pub fn destroy(server: Server) void {
        server.wl_server.destroyClients();
        server.wl_server.destroy();
    }
};

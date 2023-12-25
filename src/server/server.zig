const std = @import("std");

const wl = @import("wayland").server.wl;
const wlr = @import("wlroots");

const events = @import("../event.zig");
const Output = @import("output.zig").Output;

const gpa = std.heap.c_allocator;

pub const Server = struct {
    wl_server: *wl.Server,
    backend: *wlr.Backend,
    renderer: *wlr.Renderer,
    allocator: *wlr.Allocator,
    scene: *wlr.Scene,
    output_layout: *wlr.OutputLayout,
    scene_output_layout: *wlr.SceneOutputLayout,
    xdg_shell: *wlr.XdgShell,
    seat: *wlr.Seat,
    cursor: *wlr.Cursor,
    cursor_mgr: *wlr.XcursorManager,

    socket: [:0]const u8,
    events: events.Events,

    pub fn init(self: *Server) !void {
        const wl_server = try wl.Server.create();
        const backend = try wlr.Backend.autocreate(wl_server, null);
        const renderer = try wlr.Renderer.autocreate(backend);
        const output_layout = try wlr.OutputLayout.create();
        const scene = try wlr.Scene.create();

        var buf: [11]u8 = undefined;

        self.* = Server{
            .wl_server = wl_server,
            .backend = backend,
            .renderer = renderer,
            .allocator = try wlr.Allocator.autocreate(backend, renderer),
            .scene = scene,
            .output_layout = output_layout,
            .scene_output_layout = try scene.attachOutputLayout(output_layout),
            .xdg_shell = try wlr.XdgShell.create(wl_server, 2),
            .seat = try wlr.Seat.create(wl_server, "default"),
            .cursor = try wlr.Cursor.create(),
            .cursor_mgr = try wlr.XcursorManager.create(null, 24),
            .events = undefined,
            .socket = try wl_server.addSocketAuto(&buf),
        };
        errdefer self.destroy();

        try self.renderer.initServer(self.wl_server);
        _ = try wlr.Compositor.create(self.wl_server, 6, self.renderer);
        _ = try wlr.Subcompositor.create(self.wl_server);
        _ = try wlr.DataDeviceManager.create(self.wl_server);

        self.events.init(self);
        self.attach_events();

        self.cursor.attachOutputLayout(self.output_layout);
        try self.cursor_mgr.load(1);
    }

    fn attach_events(self: *Server) void {
        self.events.new_output.listener = &Output.onNewOutput;
    }

    pub fn destroy(self: *Server) void {
        self.wl_server.destroyClients();
        self.wl_server.destroy();
    }
};

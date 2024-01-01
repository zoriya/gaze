const std = @import("std");
const gpa = std.heap.c_allocator;

const wl = @import("wayland").server.wl;
const wlr = @import("wlroots");

const events = @import("../event.zig");
const Monitor = @import("monitor.zig").Monitor;
const Client = @import("client.zig").Client;
const Keyboard = @import("keyboard.zig").Keyboard;
const Cursor = @import("cursor.zig").Cursor;

// This needs to outlive server's socket value.
var socket_buf: [11]u8 = undefined;

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

    cursor: *Cursor,

    socket: [:0]const u8,
    events: events.Events,

    monitors: wl.list.Head(Monitor, .link) = undefined,
    clients: wl.list.Head(Client, .link) = undefined,

    pub fn init(self: *Server) !void {
        const wl_server = try wl.Server.create();
        const backend = try wlr.Backend.autocreate(wl_server, null);
        const renderer = try wlr.Renderer.autocreate(backend);
        const output_layout = try wlr.OutputLayout.create();
        const scene = try wlr.Scene.create();
        const seat = try wlr.Seat.create(wl_server, "default");

        self.* = .{
            .wl_server = wl_server,
            .backend = backend,
            .renderer = renderer,
            .allocator = try wlr.Allocator.autocreate(backend, renderer),
            .scene = scene,
            .output_layout = output_layout,
            .scene_output_layout = try scene.attachOutputLayout(output_layout),
            .xdg_shell = try wlr.XdgShell.create(wl_server, 2),
            .seat = seat,
            .cursor = try Cursor.create(self, output_layout, seat),
            .events = undefined,
            .socket = try wl_server.addSocketAuto(&socket_buf),
        };
        errdefer self.destroy();

        self.monitors.init();
        self.clients.init();

        try self.renderer.initServer(self.wl_server);
        _ = try wlr.Compositor.create(self.wl_server, 6, self.renderer);
        _ = try wlr.Subcompositor.create(self.wl_server);
        _ = try wlr.DataDeviceManager.create(self.wl_server);

        self.events.init(self);
        self.attach_events();
    }

    fn attach_events(self: *Server) void {
        self.events.new_monitor.listener = &Monitor.onNewOutput;
        self.events.new_input.listener = &onNewInput;
        self.events.new_xdg_surface.listener = &onNewSurface;
    }

    fn onNewInput(self: *Server, device: *wlr.InputDevice) void {
        switch (device.type) {
            .keyboard => Keyboard.onNewKeyboard(self, device),
            .pointer => self.cursor.onNewPointer(device),
            else => {},
        }

        // TODO: handle capabilities in a flexible way (allow touch, pointer or/and keyborads)
        self.seat.setCapabilities(.{
            .pointer = true,
            .keyboard = true,
        });
    }

    fn onNewSurface(self: *Server, xdg_surface: *wlr.XdgSurface) void {
        switch (xdg_surface.role) {
            .toplevel => Client.create(self, xdg_surface) catch {
                std.log.err("Couldn't create a client", .{});
            },
            .popup => {
                // These asserts are fine since tinywl.zig doesn't support anything else that can
                // make xdg popups (e.g. layer shell).
                const parent = wlr.XdgSurface.tryFromWlrSurface(xdg_surface.role_data.popup.?.parent.?) orelse return;
                const parent_tree = @as(?*wlr.SceneTree, @ptrFromInt(parent.data)) orelse {
                    // The xdg surface user data could be left null due to allocation failure.
                    return;
                };
                const scene_tree = parent_tree.createSceneXdgSurface(xdg_surface) catch {
                    std.log.err("failed to allocate xdg popup node", .{});
                    return;
                };
                xdg_surface.data = @intFromPtr(scene_tree);
            },
            .none => unreachable,
        }
    }

    pub fn destroy(self: *Server) void {
        self.cursor.destroy();
        self.wl_server.destroyClients();
        self.wl_server.destroy();
    }
};

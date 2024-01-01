const std = @import("std");
const gpa = std.heap.c_allocator;

const wlr = @import("wlroots");

const Server = @import("server/server.zig").Server;
const Client = @import("server/client.zig").Client;

pub fn exec(server: *Server, cmd: [:0]const u8) !void {
    var child = std.ChildProcess.init(&[_][]const u8{ "/bin/sh", "-c", cmd }, gpa);
    var env_map = try std.process.getEnvMap(gpa);
    defer env_map.deinit();
    try env_map.put("WAYLAND_DISPLAY", server.socket);
    child.env_map = &env_map;
    try child.spawn();
}

pub fn focus(server: *Server, client: *Client) !void {
    if (server.seat.keyboard_state.focused_surface) |previous_surface| {
        if (previous_surface == client.xdg_surface.surface) return;
        if (wlr.XdgSurface.tryFromWlrSurface(previous_surface)) |xdg_surface| {
            _ = xdg_surface.role_data.toplevel.?.setActivated(false);
        }
    }

    client.scene_tree.node.raiseToTop();
    _ = client.xdg_surface.role_data.toplevel.?.setActivated(true);

    const wlr_keyboard = server.seat.getKeyboard() orelse return;
    server.seat.keyboardNotifyEnter(
        client.xdg_surface.surface,
        &wlr_keyboard.keycodes,
        wlr_keyboard.num_keycodes,
        &wlr_keyboard.modifiers,
    );
}

pub const ClientAtResult = struct {
    client: *Client,
    surface: *wlr.Surface,
    x: f64,
    y: f64,
};
pub fn clientAt(server: *Server, lx: f64, ly: f64) ?ClientAtResult {
    var sx: f64 = undefined;
    var sy: f64 = undefined;
    if (server.scene.tree.node.at(lx, ly, &sx, &sy)) |node| {
        if (node.type != .buffer) return null;
        const scene_buffer = wlr.SceneBuffer.fromNode(node);
        const scene_surface = wlr.SceneSurface.tryFromBuffer(scene_buffer) orelse return null;

        var it: ?*wlr.SceneTree = node.parent;
        while (it) |n| : (it = n.node.parent) {
            if (@as(?*Client, @ptrFromInt(n.node.data))) |client| {
                return ClientAtResult{
                    .client = client,
                    .surface = scene_surface.surface,
                    .x = sx,
                    .y = sy,
                };
            }
        }
    }
    return null;
}

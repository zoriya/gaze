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

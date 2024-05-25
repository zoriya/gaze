const std = @import("std");
const gpa = std.heap.c_allocator;

const Server = @import("server.zig").Server;
const Api = @import("../commands.zig");

const wl = @import("wayland").server.wl;
const wlr = @import("wlroots");

pub const Client = struct {
    server: *Server,
    xdg_surface: *wlr.XdgSurface,
    scene_tree: *wlr.SceneTree,
    link: wl.list.Link = undefined,

    map_l: wl.Listener(void) = wl.Listener(void).init(onMap),
    unmap_l: wl.Listener(void) = wl.Listener(void).init(onUnmap),
    destroy_l: wl.Listener(void) = wl.Listener(void).init(onDestroy),

    pub fn create(server: *Server, xdg_surface: *wlr.XdgSurface) !void {
        // Don't add the client to server list until it is mapped
        const self = try gpa.create(Client);
        errdefer gpa.destroy(self);

        self.* = .{
            .server = server,
            .xdg_surface = xdg_surface,
            .scene_tree = try server.scene.tree.createSceneXdgSurface(xdg_surface),
        };
        self.scene_tree.node.data = @intFromPtr(self);
        xdg_surface.data = @intFromPtr(self.scene_tree);

        xdg_surface.surface.events.map.add(&self.map_l);
        xdg_surface.surface.events.unmap.add(&self.unmap_l);
        xdg_surface.events.destroy.add(&self.destroy_l);
    }

    pub fn destroy(self: *Client) void {
        // The client is already unlinked in the unmap event.
        self.map_l.link.remove();
        self.unmap_l.link.remove();
        self.destroy_l.link.remove();

        gpa.destroy(self);
    }

    fn onMap(listener: *wl.Listener(void)) void {
        const self: *Client = @fieldParentPtr("map_l", listener);
        self.server.clients.prepend(self);
        // TODO: remove this and add this in a lua file
        Api.focus(self.server, self) catch {};
    }

    fn onUnmap(listener: *wl.Listener(void)) void {
        const self: *Client = @fieldParentPtr("unmap_l", listener);
        self.link.remove();
    }

    fn onDestroy(listener: *wl.Listener(void)) void {
        const self: *Client = @fieldParentPtr("destroy_l", listener);
        self.destroy();
    }
};

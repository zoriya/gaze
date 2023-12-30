const std = @import("std");

const Server = @import("server.zig").Server;

const wl = @import("wayland").server.wl;
const wlr = @import("wlroots");

const gpa = std.heap.c_allocator;

pub const Client = struct {
    server: *Server,
    surface: *wlr.XdgSurface,
    scene_tree: *wlr.SceneTree,
    link: wl.list.Link = undefined,

    map_l: wl.Listener(void) = wl.Listener(void).init(onMap),
    unmap_l: wl.Listener(void) = wl.Listener(void).init(onUnmap),
    destroy_l: wl.Listener(void) = wl.Listener(void).init(onDestroy),

    pub fn create(server: *Server, surface: *wlr.XdgSurface) !void {
        // Don't add the client to server list until it is mapped
        const self = try gpa.create(Client);
        errdefer gpa.destroy(self);

        self.* = .{
            .server = server,
            .surface = surface,
            .scene_tree = try server.scene.tree.createSceneXdgSurface(surface),
        };
        self.scene_tree.node.data = @intFromPtr(self);
        surface.data = @intFromPtr(self);

        surface.surface.events.map.add(&self.map_l);
        surface.surface.events.unmap.add(&self.unmap_l);
        surface.events.destroy.add(&self.destroy_l);
    }

    pub fn destroy(self: *Client) void {
        self.link.remove();

        self.map_l.link.remove();
        self.unmap_l.link.remove();
        self.destroy_l.link.remove();

        gpa.destroy(self);
    }

    fn onMap(listener: *wl.Listener(void)) void {
        const self = @fieldParentPtr(Client, "map_l", listener);
        self.server.clients.prepend(self);
    }

    fn onUnmap(listener: *wl.Listener(void)) void {
        const self = @fieldParentPtr(Client, "unmap_l", listener);
        self.link.remove();
    }

    fn onDestroy(listener: *wl.Listener(void)) void {
        const self = @fieldParentPtr(Client, "destroy_l", listener);
        self.destroy();
    }
};

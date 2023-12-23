const std = @import("std");

const wl = @import("wayland").server.wl;
const wlr = @import("wlroots");

const events = @import("event.zig");

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

    events: events.Events,

    pub fn init(self: *Server) !void {
        const wl_server = try wl.Server.create();
        const backend = try wlr.Backend.autocreate(wl_server, null);
        const renderer = try wlr.Renderer.autocreate(backend);
        const output_layout = try wlr.OutputLayout.create();
        const scene = try wlr.Scene.create();

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
        self.events.new_output.listener = &onNewOutput;
    }

    pub fn destroy(self: *Server) void {
        self.wl_server.destroyClients();
        self.wl_server.destroy();
    }

    fn onNewOutput(self: *Server, wlr_output: *wlr.Output) void {
        if (!wlr_output.initRender(self.allocator, self.renderer)) return;

        var state = wlr.Output.State.init();
        defer state.finish();

        state.setEnabled(true);
        if (wlr_output.preferredMode()) |mode| {
            state.setMode(mode);
        }
        if (!wlr_output.commitState(&state)) return;

        _ = Output.create(self, wlr_output) catch {
            std.log.err("failed to allocate new output", .{});
            return;
        };
    }
};

const Output = struct {
    server: *Server,
    wlr_output: *wlr.Output,

    frame: wl.Listener(*wlr.Output) = wl.Listener(*wlr.Output).init(frame),
    request_state: wl.Listener(*wlr.Output.event.RequestState) =
        wl.Listener(*wlr.Output.event.RequestState).init(request_state),
    // TODO: replace that with an Event for lua events support
    destroy: wl.Listener(*wlr.Output) = wl.Listener(*wlr.Output).init(destroy),

    /// Ouput takes ownership of of the wlr_output. If create fail, Ouput will
    /// destroy the wlr.Ouput.
    fn create(server: *Server, wlr_output: *wlr.Output) !*Output {
        errdefer wlr_output.destroy();

        const self = try gpa.create(Output);
        self.* = .{
            .server = server,
            .wlr_output = wlr_output,
        };
        wlr_output.events.frame.add(&self.frame);
        wlr_output.events.request_state.add(&self.request_state);
        wlr_output.events.destroy.add(&self.destroy);

        const layout_output = try server.output_layout.addAuto(wlr_output);
        const scene_output = try server.scene.createSceneOutput(wlr_output);
        server.scene_output_layout.addOutput(layout_output, scene_output);
        return self;
    }

    fn destroy(listener: *wl.Listener(*wlr.Output), _: *wlr.Output) void {
        const output = @fieldParentPtr(Output, "destroy", listener);

        output.frame.link.remove();
        output.request_state.link.remove();
        output.destroy.link.remove();

        gpa.destroy(output);
    }

    fn frame(listener: *wl.Listener(*wlr.Output), _: *wlr.Output) void {
        const output = @fieldParentPtr(Output, "frame", listener);

        const scene_output = output.server.scene.getSceneOutput(output.wlr_output).?;
        _ = scene_output.commit(null);

        var now: std.os.timespec = undefined;
        std.os.clock_gettime(std.os.CLOCK.MONOTONIC, &now) catch @panic("CLOCK_MONOTONIC not supported");
        scene_output.sendFrameDone(&now);
    }

    fn request_state(
        listener: *wl.Listener(*wlr.Output.event.RequestState),
        event: *wlr.Output.event.RequestState,
    ) void {
        const output = @fieldParentPtr(Output, "request_state", listener);

        _ = output.wlr_output.commitState(event.state);
    }
};

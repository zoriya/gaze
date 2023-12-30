const std = @import("std");

const Server = @import("server.zig").Server;

const wl = @import("wayland").server.wl;
const wlr = @import("wlroots");

const gpa = std.heap.c_allocator;

pub const Monitor = struct {
    server: *Server,
    wlr_output: *wlr.Output,

    frame: wl.Listener(*wlr.Output) = wl.Listener(*wlr.Output).init(frame),
    request_state: wl.Listener(*wlr.Output.event.RequestState) =
        wl.Listener(*wlr.Output.event.RequestState).init(request_state),
    // TODO: replace that with an Event for lua events support
    destroy: wl.Listener(*wlr.Output) = wl.Listener(*wlr.Output).init(destroy),

    pub fn onNewOutput(server: *Server, wlr_output: *wlr.Output) void {
        if (!wlr_output.initRender(server.allocator, server.renderer)) return;

        var state = wlr.Output.State.init();
        defer state.finish();

        state.setEnabled(true);
        if (wlr_output.preferredMode()) |mode| {
            state.setMode(mode);
        }
        if (!wlr_output.commitState(&state)) return;

        _ = create(server, wlr_output) catch {
            std.log.err("failed to allocate new output", .{});
            return;
        };
    }

    /// Ouput takes ownership of of the wlr_output. If create fail, Ouput will
    /// destroy the wlr.Ouput.
    fn create(server: *Server, wlr_output: *wlr.Output) !*Monitor {
        errdefer wlr_output.destroy();

        const self = try gpa.create(Monitor);
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
        const output = @fieldParentPtr(Monitor, "destroy", listener);

        output.frame.link.remove();
        output.request_state.link.remove();
        output.destroy.link.remove();

        gpa.destroy(output);
    }

    fn frame(listener: *wl.Listener(*wlr.Output), _: *wlr.Output) void {
        const output = @fieldParentPtr(Monitor, "frame", listener);

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
        const output = @fieldParentPtr(Monitor, "request_state", listener);

        _ = output.wlr_output.commitState(event.state);
    }
};

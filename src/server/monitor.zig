const std = @import("std");

const Server = @import("server.zig").Server;

const wl = @import("wayland").server.wl;
const wlr = @import("wlroots");

const gpa = std.heap.c_allocator;

pub const Monitor = struct {
    server: *Server,
    wlr_output: *wlr.Output,
    link: wl.list.Link = undefined,

    frame_l: wl.Listener(*wlr.Output) = wl.Listener(*wlr.Output).init(onFrame),
    request_state_l: wl.Listener(*wlr.Output.event.RequestState) =
        wl.Listener(*wlr.Output.event.RequestState).init(onRequestState),
    // TODO: replace that with an Event for lua events support
    destroy_l: wl.Listener(*wlr.Output) = wl.Listener(*wlr.Output).init(onDestroy),

    pub fn onNewOutput(server: *Server, wlr_output: *wlr.Output) void {
        if (!wlr_output.initRender(server.allocator, server.renderer)) return;

        var state = wlr.Output.State.init();
        defer state.finish();

        state.setEnabled(true);
        if (wlr_output.preferredMode()) |mode| {
            state.setMode(mode);
        }
        if (!wlr_output.commitState(&state)) return;

        const mon = create(server, wlr_output) catch {
            std.log.err("failed to allocate new output", .{});
            return;
        };
        server.monitors.append(mon);
    }

    /// Ouput takes ownership of of the wlr_output. If create fail, Ouput will
    /// destroy the wlr.Ouput.
    fn create(server: *Server, wlr_output: *wlr.Output) !*Monitor {
        errdefer wlr_output.destroy();

        const self = try gpa.create(Monitor);
        errdefer gpa.destroy(self);
        self.* = .{
            .server = server,
            .wlr_output = wlr_output,
        };
        wlr_output.events.frame.add(&self.frame_l);
        wlr_output.events.request_state.add(&self.request_state_l);
        wlr_output.events.destroy.add(&self.destroy_l);

        const layout_output = try server.output_layout.addAuto(wlr_output);
        const scene_output = try server.scene.createSceneOutput(wlr_output);
        server.scene_output_layout.addOutput(layout_output, scene_output);
        return self;
    }

    fn destroy(self: *Monitor) void {
        self.link.remove();

        self.frame_l.link.remove();
        self.request_state_l.link.remove();
        self.destroy_l.link.remove();

        gpa.destroy(self);
    }

    fn onDestroy(listener: *wl.Listener(*wlr.Output), _: *wlr.Output) void {
        const self: *Monitor = @fieldParentPtr("destroy_l", listener);
        self.destroy();
    }

    fn onFrame(listener: *wl.Listener(*wlr.Output), _: *wlr.Output) void {
        const output: *Monitor = @fieldParentPtr("frame_l", listener);

        const scene_output = output.server.scene.getSceneOutput(output.wlr_output).?;
        _ = scene_output.commit(null);

        var now: std.posix.timespec = undefined;
        std.posix.clock_gettime(std.posix.CLOCK.MONOTONIC, &now) catch @panic("CLOCK_MONOTONIC not supported");
        scene_output.sendFrameDone(&now);
    }

    fn onRequestState(
        listener: *wl.Listener(*wlr.Output.event.RequestState),
        event: *wlr.Output.event.RequestState,
    ) void {
        const output: *Monitor = @fieldParentPtr("request_state_l", listener);

        _ = output.wlr_output.commitState(event.state);
    }
};

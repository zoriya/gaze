const std = @import("std");
const gpa = std.heap.c_allocator;

const wl = @import("wayland").server.wl;
const wlr = @import("wlroots");

const Server = @import("server.zig").Server;

pub const Cursor = struct {
    server: *Server,
    cursor: *wlr.Cursor,
    cursor_mgr: *wlr.XcursorManager,

    motion: wl.Listener(*wlr.Pointer.event.Motion) = wl.Listener(*wlr.Pointer.event.Motion).init(onMotion),
    motion_absolute: wl.Listener(*wlr.Pointer.event.MotionAbsolute) = wl.Listener(*wlr.Pointer.event.MotionAbsolute).init(onMotionAbsolute),
    button: wl.Listener(*wlr.Pointer.event.Button) = wl.Listener(*wlr.Pointer.event.Button).init(onButton),
    axis: wl.Listener(*wlr.Pointer.event.Axis) = wl.Listener(*wlr.Pointer.event.Axis).init(onAxis),
    frame: wl.Listener(*wlr.Cursor) = wl.Listener(*wlr.Cursor).init(onFrame),

    pub fn onNewPointer(self: *Cursor, device: *wlr.InputDevice) void {
        self.cursor.attachInputDevice(device);
    }

    pub fn create(server: *Server) !*Cursor {
        const self = try gpa.create(Cursor);
        errdefer gpa.destroy(self);
        self.* = .{
            .server = server,
            .cursor = try wlr.Cursor.create(),
            .cursor_mgr = try wlr.XcursorManager.create(null, 24),
        };

        self.cursor.attachOutputLayout(server.output_layout);
        try self.cursor_mgr.load(1);

        self.cursor.events.motion.add(&self.motion);
        self.cursor.events.motion_absolute.add(&self.motion_absolute);
        self.cursor.events.button.add(&self.button);
        self.cursor.events.axis.add(&self.axis);
        self.cursor.events.frame.add(&self.frame);
        return self;
    }

    pub fn destroy(self: *Cursor) void {
        self.motion.link.remove();
        self.motion_absolute.link.remove();
        self.button.link.remove();
        self.axis.link.remove();
        self.frame.link.remove();
        gpa.destroy(self);
    }

    fn onMotion(
        listener: *wl.Listener(*wlr.Pointer.event.Motion),
        event: *wlr.Pointer.event.Motion,
    ) void {
        const self = @fieldParentPtr(Cursor, "motion", listener);
        self.cursor.move(event.device, event.delta_x, event.delta_y);
    }

    fn onMotionAbsolute(
        listener: *wl.Listener(*wlr.Pointer.event.MotionAbsolute),
        event: *wlr.Pointer.event.MotionAbsolute,
    ) void {
        const self = @fieldParentPtr(Cursor, "motion_absolute", listener);
        self.cursor.warpAbsolute(event.device, event.x, event.y);
    }

    fn onButton(
        listener: *wl.Listener(*wlr.Pointer.event.Button),
        event: *wlr.Pointer.event.Button,
    ) void {
        const self = @fieldParentPtr(Cursor, "button", listener);
        _ = self.server.seat.pointerNotifyButton(event.time_msec, event.button, event.state);
    }

    fn onAxis(
        listener: *wl.Listener(*wlr.Pointer.event.Axis),
        event: *wlr.Pointer.event.Axis,
    ) void {
        const self = @fieldParentPtr(Cursor, "axis", listener);
        self.server.seat.pointerNotifyAxis(
            event.time_msec,
            event.orientation,
            event.delta,
            event.delta_discrete,
            event.source,
        );
    }

    fn onFrame(listener: *wl.Listener(*wlr.Cursor), _: *wlr.Cursor) void {
        const self = @fieldParentPtr(Cursor, "frame", listener);
        self.server.seat.pointerNotifyFrame();
    }
};

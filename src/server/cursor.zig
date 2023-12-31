const std = @import("std");
const gpa = std.heap.c_allocator;

const wl = @import("wayland").server.wl;
const wlr = @import("wlroots");

const Server = @import("server.zig").Server;
const Api = @import("../commands.zig");

pub const Cursor = struct {
    server: *Server,
    cursor: *wlr.Cursor,
    cursor_mgr: *wlr.XcursorManager,

    motion: wl.Listener(*wlr.Pointer.event.Motion) = wl.Listener(*wlr.Pointer.event.Motion).init(onMotion),
    motion_absolute: wl.Listener(*wlr.Pointer.event.MotionAbsolute) = wl.Listener(*wlr.Pointer.event.MotionAbsolute).init(onMotionAbsolute),
    button: wl.Listener(*wlr.Pointer.event.Button) = wl.Listener(*wlr.Pointer.event.Button).init(onButton),
    axis: wl.Listener(*wlr.Pointer.event.Axis) = wl.Listener(*wlr.Pointer.event.Axis).init(onAxis),
    frame: wl.Listener(*wlr.Cursor) = wl.Listener(*wlr.Cursor).init(onFrame),

    request_set_cursor_l: wl.Listener(*wlr.Seat.event.RequestSetCursor) = wl.Listener(*wlr.Seat.event.RequestSetCursor).init(onRequestSetCursor),
    request_set_selection_l: wl.Listener(*wlr.Seat.event.RequestSetSelection) = wl.Listener(*wlr.Seat.event.RequestSetSelection).init(onRequestSetSelection),

    pub fn onNewPointer(self: *Cursor, device: *wlr.InputDevice) void {
        self.cursor.attachInputDevice(device);
    }

    pub fn create(server: *Server, output_layout: *wlr.OutputLayout, seat: *wlr.Seat) !*Cursor {
        const self = try gpa.create(Cursor);
        errdefer gpa.destroy(self);
        self.* = .{
            .server = server,
            .cursor = try wlr.Cursor.create(),
            .cursor_mgr = try wlr.XcursorManager.create(null, 24),
        };

        self.cursor.attachOutputLayout(output_layout);
        try self.cursor_mgr.load(1);

        self.cursor.events.motion.add(&self.motion);
        self.cursor.events.motion_absolute.add(&self.motion_absolute);
        self.cursor.events.button.add(&self.button);
        self.cursor.events.axis.add(&self.axis);
        self.cursor.events.frame.add(&self.frame);

        seat.events.request_set_cursor.add(&self.request_set_cursor_l);
        seat.events.request_set_selection.add(&self.request_set_selection_l);
        return self;
    }

    pub fn destroy(self: *Cursor) void {
        self.request_set_cursor_l.link.remove();
        self.request_set_selection_l.link.remove();

        self.motion.link.remove();
        self.motion_absolute.link.remove();
        self.button.link.remove();
        self.axis.link.remove();
        self.frame.link.remove();

        gpa.destroy(self);
    }

    fn handleMotion(self: *Cursor, time_msec: u32) void {
        if (Api.clientAt(self.server, self.cursor.x, self.cursor.y)) |res| {
            self.server.seat.pointerNotifyEnter(res.surface, res.x, res.y);
            self.server.seat.pointerNotifyMotion(time_msec, res.x, res.y);
        } else {
            self.cursor.setXcursor(self.cursor_mgr, "default");
            self.server.seat.pointerClearFocus();
        }
    }

    fn onMotion(
        listener: *wl.Listener(*wlr.Pointer.event.Motion),
        event: *wlr.Pointer.event.Motion,
    ) void {
        const self = @fieldParentPtr(Cursor, "motion", listener);
        self.cursor.move(event.device, event.delta_x, event.delta_y);
        self.handleMotion(event.time_msec);
    }

    fn onMotionAbsolute(
        listener: *wl.Listener(*wlr.Pointer.event.MotionAbsolute),
        event: *wlr.Pointer.event.MotionAbsolute,
    ) void {
        const self = @fieldParentPtr(Cursor, "motion_absolute", listener);
        self.cursor.warpAbsolute(event.device, event.x, event.y);
        self.handleMotion(event.time_msec);
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

    fn onRequestSetCursor(
        listener: *wl.Listener(*wlr.Seat.event.RequestSetCursor),
        event: *wlr.Seat.event.RequestSetCursor,
    ) void {
        const self = @fieldParentPtr(Cursor, "request_set_cursor_l", listener);
        if (event.seat_client == self.server.seat.pointer_state.focused_client)
            self.cursor.setSurface(event.surface, event.hotspot_x, event.hotspot_y);
    }

    fn onRequestSetSelection(
        listener: *wl.Listener(*wlr.Seat.event.RequestSetSelection),
        event: *wlr.Seat.event.RequestSetSelection,
    ) void {
        const self = @fieldParentPtr(Cursor, "request_set_selection_l", listener);
        self.server.seat.setSelection(event.source, event.serial);
    }
};

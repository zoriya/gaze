const std = @import("std");

const Server = @import("server.zig").Server;

const wl = @import("wayland").server.wl;
const wlr = @import("wlroots");
const xkb = @import("xkbcommon");

const gpa = std.heap.c_allocator;

pub const Keyboard = struct {
    server: *Server,
    device: *wlr.Keyboard,

    modifiers: wl.Listener(*wlr.Keyboard) = wl.Listener(*wlr.Keyboard).init(modifiers),
    key: wl.Listener(*wlr.Keyboard.event.Key) = wl.Listener(*wlr.Keyboard.event.Key).init(key),

    pub fn onNewKeyboard(server: *Server, device: *wlr.InputDevice) void {
        const keyboard = Keyboard.create(server, device) catch |err| {
            std.log.err("failed to create keyboard: {}", .{err});
            return;
        };
        server.seat.setKeyboard(keyboard.device);
        // TODO: should keyboards be stored on the server struct?
        // TODO: destroy keyboards when unused. I dont think the destroy event of wlroots
        // is binded in zig so now we leak memory.
    }

    fn create(server: *Server, device: *wlr.InputDevice) !*Keyboard {
        const self = try gpa.create(Keyboard);
        errdefer gpa.destroy(self);

        self.* = .{
            .server = server,
            .device = device.toKeyboard(),
        };

        const context = xkb.Context.new(.no_flags) orelse return error.ContextFailed;
        defer context.unref();
        const keymap = xkb.Keymap.newFromNames(context, null, .no_flags) orelse return error.KeymapFailed;
        defer keymap.unref();

        if (!self.device.setKeymap(keymap)) return error.SetKeymapFailed;
        self.device.setRepeatInfo(25, 600);

        self.device.events.modifiers.add(&self.modifiers);
        self.device.events.key.add(&self.key);
        return self;
    }

    fn modifiers(listener: *wl.Listener(*wlr.Keyboard), wlr_keyboard: *wlr.Keyboard) void {
        const keyboard = @fieldParentPtr(Keyboard, "modifiers", listener);
        keyboard.server.seat.setKeyboard(wlr_keyboard);
        keyboard.server.seat.keyboardNotifyModifiers(&wlr_keyboard.modifiers);
    }

    fn key(listener: *wl.Listener(*wlr.Keyboard.event.Key), event: *wlr.Keyboard.event.Key) void {
        const keyboard = @fieldParentPtr(Keyboard, "key", listener);
        const wlr_keyboard = keyboard.device.toKeyboard();

        // TODO: Actually handle keybinds in gaze. Bellow is what was used in tinywl.
        // // Translate libinput keycode -> xkbcommon
        // const keycode = event.keycode + 8;
        // if (wlr_keyboard.getModifiers().alt and event.state == .pressed) {
        //     for (wlr_keyboard.xkb_state.?.keyGetSyms(keycode)) |sym| {
        //         if (keyboard.server.handleKeybind(sym)) {
        //             return;
        //         }
        //     }
        // }

        keyboard.server.seat.setKeyboard(wlr_keyboard);
        keyboard.server.seat.keyboardNotifyKey(event.time_msec, event.keycode, event.state);
    }
};

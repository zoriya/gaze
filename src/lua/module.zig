const std = @import("std");

pub const Module = struct {
    name: [:0]const u8,
    enabled: enum { true, false, default },
    // options: obj,
};

pub const Config = struct {
    name: [:0]const u8,
    default: bool,
    // keymaps: std.ArrayList(Keymap),
    // events: Events,
};


const std = @import("std");
const gpa = std.heap.c_allocator;

const Command = @import("../commands.zig");
const conf = @import("module.zig");

const ziglua = @import("ziglua");
const Lua = ziglua.Lua;

pub const LuaRuntime = struct {
    lua: Lua,
    config: std.ArrayList(conf.Config),

    pub fn create() !LuaRuntime {
        const self = try gpa.create(LuaRuntime);
        errdefer gpa.destroy(self);

        const lua = try Lua.init(gpa);
        errdefer lua.deinit();

        self.* = .{
            .handle = lua,
        };
        self.init();
        try self.readConfig();
        return self;
    }

    pub fn destroy(self: *LuaRuntime) void {
        self.lua.deinit();
        gpa.destroy(self);
    }

    fn init(self: *LuaRuntime) void {
        self.lua.newTable();
        self.lua.setGlobal("gaze");

        const gaze = .{
            .api = .{
                .exec = Command.exec,
            },
            // inspect(tbl),
            // current_client,
            // current_monitor,
        };
        // TODO: actually set the global gaze from the value above (not an empty table)
        _ = gaze;
    }

    pub fn readConfig(self: *LuaRuntime) !std.ArrayList(conf.Config) {
        self.lua.doFile("/home/zoriya/projects/gaze/runtime/init.lua") catch |err| switch (err) {
            error.Syntax => {
                std.log.err("Invalid lua syntax.");
                return err;
            },
            error.Runtime => {
                std.log.err("Runtime lua error while getting config: {s}", .{self.lua.toString(-1)});
                // Remove the error from the stack.
                self.lua.pop(1);
                return err;
            },
            else => return err,
        };
        const configs = self.lua.to;
        self.lua.pop(1);
        // TODO: uninit this
        return std.ArrayList(conf.Config).init(gpa);
        // const modules = self.parseModules();

        // const config = self.readConfigAt(systemRuntime) catch |err| switch (err) {
        //     error.InvalidConfig => return error.InvaliSystemConfig,
        //     else => return err,
        // };
        // const userConfig =self.readConfigAt(userRuntime) catch |err| switch (err) {
        //     error.InvalidConfig => unreachable,
        //     else => return err,
        // };

        // // TODO: merge config and user config.
        // return config;
    }

    // pub fn parseModules(self: *LuaRuntime) !std.ArrayList(Module) {
    //     unreachable;
    // }
    //
    // pub fn parseModule(self: *LuaRuntime, path: [:0]const u8) !Module {
    //     unreachable;
    // }
    //
    // pub fn readConfigAt(self: *LuaRuntime, path: [:0]const u8) void {
    //     unreachable;
    // }
};

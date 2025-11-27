const std = @import("std");

const MyCustomInterface = @import("interface.zig");

const ImplInterfaceTwo = @This();

uuid: []const u8 = "",

const Error = error{NameAlreadyExists};

pub fn hello(ptr: *anyopaque) void {
    const self: *ImplInterfaceTwo = @ptrCast(@alignCast(ptr));

    std.debug.print("In interface two ({s}) we don't say hello. GET OUT\n", .{self.uuid});
}

pub fn ping(ptr: *anyopaque) void {
    _ = ptr;
    std.debug.print("WHAT ABOUT PONG?\n", .{});
}

pub fn getName(ptr: *anyopaque) []const u8 {
    _ = ptr;

    std.debug.print("No matter what they say, we will always return 'potato'\n", .{});

    return "potato";
}

pub fn setName(ptr: *anyopaque, name: []const u8) Error!void {
    _ = ptr;

    if (std.mem.eql(u8, name, "potato")) {
        return Error.NameAlreadyExists;
    }

    std.debug.print("I'm not even using the ptr. Won't do anything.", .{});
}

pub fn init(self: *ImplInterfaceTwo, uuid: []const u8) MyCustomInterface {
    self.uuid = uuid;

    return .{ .ptr = self, .vtable = &.{ .hello = hello, .ping = ping, .getName = getName, .setName = setName } };
}

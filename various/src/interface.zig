const std = @import("std");

const MyCustomInterface = @This();

ptr: *anyopaque,
vtable: *const VTable,

const VTable = struct {
    hello: *const fn (*anyopaque) void,
    ping: *const fn (*anyopaque) void,
    getName: *const fn (*anyopaque) []const u8,
    setName: *const fn (*anyopaque, name: []const u8) anyerror!void,
};

pub fn hello(self: MyCustomInterface) void {
    return self.vtable.hello(self.ptr);
}

pub fn ping(self: MyCustomInterface) void {
    return self.vtable.ping(self.ptr);
}

pub fn getName(self: MyCustomInterface) []const u8 {
    return self.vtable.getName(self.ptr);
}

pub fn setName(self: MyCustomInterface, name: []const u8) !void {
    return self.vtable.setName(self.ptr, name);
}

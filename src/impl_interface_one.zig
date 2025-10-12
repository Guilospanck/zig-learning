// ! This implements the MyCustomInterface from `interface.zig`.
//

const std = @import("std");
const MyCustomInterface = @import("interface.zig");

const ImplInterfaceOne = @This();

id: []const u8 = "",
name: []const u8 = "",

const Error = error{NameCannotBeEmpty};

pub fn hello(ptr: *anyopaque) void {
    // This "un-erase" the type: *anyopaque -> *ImplInterfaceOne
    const self: *ImplInterfaceOne = @ptrCast(@alignCast(ptr));

    std.debug.print("Hello from Interface one id {s}\n", .{self.id});
}

pub fn ping(ptr: *anyopaque) void {
    const self: *ImplInterfaceOne = @ptrCast(@alignCast(ptr));

    std.debug.print("Ping from Interface one id {s}\n", .{self.id});
}

pub fn getName(ptr: *anyopaque) []const u8 {
    const self: *ImplInterfaceOne = @ptrCast(@alignCast(ptr));

    return self.name;
}

pub fn setName(ptr: *anyopaque, name: []const u8) Error!void {
    const self: *ImplInterfaceOne = @ptrCast(@alignCast(ptr));

    if (name.len == 0) {
        return Error.NameCannotBeEmpty;
    }

    self.name = name;

    std.debug.print("Name set to {s}\n", .{name});
}

pub fn init(self: *ImplInterfaceOne, id: []const u8) MyCustomInterface {
    // TODO: implement uuid
    self.id = id;

    return .{
        // This erases the type: *ImplInterfaceOne -> *anyopaque
        .ptr = self,
        .vtable = &.{
            .hello = hello,
            .ping = ping,
            .getName = getName,
            .setName = setName,
        },
    };
}

const std = @import("std");

const OptionEnum = enum { Some, None };

// The type (generic (comptime) tagged union)
fn Option(comptime T: type) type {
    return union(OptionEnum) { Some: T, None };
}

// Helper functions
fn some(comptime T: type, value: T) Option(T) {
    return Option(T){ .Some = value };
}

fn none(comptime T: type) Option(T) {
    return Option(T){ .None = {} };
}

fn isSome(comptime T: type, option: Option(T)) bool {
    return switch (option) {
        .None => false,
        .Some => true,
    };
}

fn isNone(comptime T: type, option: Option(T)) bool {
    return switch (option) {
        .None => true,
        .Some => false,
    };
}

// Just for test
fn getValue(x: u32) Option(u32) {
    return if (x > 5) some(u32, x) else none(u32);
}

pub fn optionTest(random: u32) void {
    const val = getValue(random);
    switch (val) {
        .Some => |value| std.debug.print("Some: {d}\n", .{value}),
        .None => std.debug.print("None\n", .{}),
    }
}

test "Some" {
    const value: u32 = 16;
    const some_value = Option(@TypeOf(value)){ .Some = value };

    try std.testing.expect(@TypeOf(some_value) == Option(u32));
    try std.testing.expect(isSome(@TypeOf(value), some_value));
}

test "None" {
    const value: void = {};
    const none_value = Option(@TypeOf(value)){ .None = value };
    try std.testing.expect(@TypeOf(none_value) == Option(void));
    try std.testing.expect(isNone(@TypeOf(value), none_value));

    const value2: u64 = 22;
    const none_value2 = Option(@TypeOf(value2)){ .None = value };
    try std.testing.expect(@TypeOf(none_value2) == Option(u64));
    try std.testing.expect(isNone(@TypeOf(value2), none_value2));
}

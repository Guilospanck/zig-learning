const std = @import("std");
// TODO: take a look into std.log for proper logging
// This prints to stderr
const print = std.debug.print;

// my own module
const URLBuilder = @import("url_builder.zig");

// This is defined in the `addExecutable` in `build.zig` in the section of `imports`.
const potato = @import("potato");

const ArgParseError = error{ MissingValue, InvalidValue, UnknownValue };

const CliArgs = struct {
    name: []const u8 = "",
    age: u8 = 0,
    address: []const u8 = "",
    pub fn format(
        self: @This(),
        writer: *std.Io.Writer,
    ) std.Io.Writer.Error!void {
        try writer.print("CliArgs: {{ \nname = {s},\nage = {d},\naddress = {s}\n}}\n", .{ self.name, self.age, self.address });
    }
};

fn gotoLikeSwitch() void {
    std.debug.print("--------------- GOTO like switch --------------- \n", .{});
    mylabel: switch (@as(u8, 1)) {
        1 => {
            std.debug.print("First branch\n", .{});
            continue :mylabel 2;
        },
        2 => {
            print("Second branch\n", .{});
            continue :mylabel 3;
        },
        3 => {
            std.debug.print("third branch\n", .{});
            continue :mylabel 4;
        },
        4 => {},
        5 => return, // this returns from the function that contains switch statement
        else => {
            std.debug.print("Unmatched", .{});
        },
    }
    std.debug.print("------------------------------------------------ \n", .{});
}

// NOTE: we can only get the args from the user because in `build.zig`
// we allow it with `.addArgs`.
fn parseArgs(allocator: std.mem.Allocator) !CliArgs {
    // `try` are like `.unwrap()` in rust.
    // Do not use `try` and `catch` on the same value.
    var args = try std.process.argsWithAllocator(allocator);
    defer args.deinit();

    // Remove the program name
    _ = args.next();

    var result = CliArgs{};

    while (args.next()) |arg| {
        if (std.mem.eql(u8, arg, "--name")) {
            const name = args.next() orelse return ArgParseError.MissingValue;
            result.name = name;
        } else if (std.mem.eql(u8, arg, "--address")) {
            const address = args.next() orelse return ArgParseError.MissingValue;
            result.address = address;
        } else if (std.mem.eql(u8, arg, "--age")) {
            const age = args.next() orelse return ArgParseError.MissingValue;
            // check if it is u8
            const age_number = std.fmt.parseInt(u8, age, 10) catch {
                return ArgParseError.InvalidValue;
            };
            result.age = age_number;
        } else {
            // `return` inside a while loop will break the while
            // AND return the function.
            return ArgParseError.UnknownValue;
        }
    }

    return result;
}

fn buildURLs(allocator: std.mem.Allocator) !void {
    // URL builder
    var builder = URLBuilder.init();
    const url = try builder.withProtocol(.HTTPS).withDomain("guilospanck.com").build(allocator);
    const url2 = try builder.withProtocol(.HTTP).withDomain("localhost").withPort(4444).build(allocator);
    print("{s}\n{s}", .{ url, url2 });

    defer allocator.free(url2);
    defer allocator.free(url);
}

pub fn main() !void {
    // Instantiates our allocator
    var debugAlloc: std.heap.DebugAllocator(.{}) = .init;
    const allocator = debugAlloc.allocator();
    // After we’re done with all allocations, deinit the DebugAllocator
    // This will check for leaks, double-frees, etc.
    defer {
        const deinit_result = debugAlloc.deinit();
        if (deinit_result != .ok) {
            std.debug.print("DebugAllocator deinit reported error: {any}\n", .{deinit_result});
        }
    }

    // Prints to stderr, ignoring potential errors.
    try potato.bufferedPrint();

    const parsedArgs = parseArgs(allocator) catch |err| {
        print("Error parsing args: {s}\n", .{@errorName(err)});
        return err;
    };

    print("{f}\n", .{parsedArgs});

    gotoLikeSwitch();
    print("\n", .{});

    try buildURLs(allocator);
}

test "build urls" {
    const allocator = std.testing.allocator;
    const expected_url: []const u8 = "http://localhost:4444";

    var builder = URLBuilder.init();

    const url = try builder.withProtocol(.HTTP).withPort(4444).withDomain("localhost").build(allocator);
    defer allocator.free(url);

    try std.testing.expect(std.mem.eql(u8, expected_url, url));
}

test "simple test" {
    const gpa = std.testing.allocator;
    var list: std.ArrayList(i32) = .empty;
    defer list.deinit(gpa); // Try commenting this out and see if zig detects the memory leak!
    try list.append(gpa, 42);
    try std.testing.expectEqual(@as(i32, 42), list.pop());
}

test "fuzz example" {
    const Context = struct {
        fn testOne(context: @This(), input: []const u8) anyerror!void {
            _ = context;
            // Try passing `--fuzz` to `zig build test` and see if it manages to fail this test case!
            try std.testing.expect(!std.mem.eql(u8, "canyoufindme", input));
        }
    };
    try std.testing.fuzz(Context{}, Context.testOne, .{});
}

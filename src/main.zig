const std = @import("std");
const print = std.debug.print;

// This is defined in the `addExecutable` in `build.zig` in the section of `imports`.
const potato = @import("potato");

const ArgParseError = error{ MissingValue, InvalidValue, UnknownValue };

const CliArgs = struct {
    name: []const u8,
    age: u8,
    pub fn format(
        self: @This(),
        writer: *std.Io.Writer,
    ) std.Io.Writer.Error!void {
        try writer.print("CliArgs: {{ name = {s}, age = {d} }}\n", .{ self.name, self.age });
    }
};

// NOTE: we can only get the args from the user because in `build.zig`
// we allow it with `.addArgs`.
fn parseArgs() !CliArgs {
    const allocator = std.heap.smp_allocator;
    // `try` are like `.unwrap()` in rust.
    // Do not use `try` and `catch` on the same value.
    var args = try std.process.argsWithAllocator(allocator);
    defer args.deinit();

    // Remove the program name
    _ = args.next();

    var result: CliArgs = undefined;

    while (args.next()) |arg| {
        if (std.mem.eql(u8, arg, "--name")) {
            const name = args.next() orelse return ArgParseError.MissingValue;
            result.name = name;
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

pub fn main() !void {
    // Prints to stderr, ignoring potential errors.
    try potato.bufferedPrint();

    const parsedArgs = parseArgs() catch |err| {
        print("Error parsing args: {s}\n", .{@errorName(err)});
        return err;
    };

    print("{f}", .{parsedArgs});
    print("The name is {s} and the age is {d}\n", .{ parsedArgs.name, parsedArgs.age });
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

const std = @import("std");

const ArgsParseError = error{InvalidArgsLength};

fn getFilepathFromArgs(allocator: std.mem.Allocator) ArgsParseError![]const u8 {
    var args = try std.process.argsWithAllocator(allocator);
    defer args.deinit();

    // Remove program name
    _ = args.next();

    const filepath = args.next() orelse return ArgsParseError.InvalidArgsLength;

    if (args.next()) |_| return ArgsParseError.InvalidArgsLength;

    return filepath;
}

fn print(comptime fmt: []const u8, args: anytype) !void {
    var stdout_buffer: [1024]u8 = undefined;
    var stdout_writer = std.fs.File.stdout().writer(&stdout_buffer);
    const stdout = &stdout_writer.interface;

    try stdout.print(fmt, args);
    try stdout.flush();
}

fn readFileAndPrintToStdout(filepath: []const u8) !void {
    // get current working directory
    const cwd = std.fs.cwd();

    // open the file as read-only
    const file = try cwd.openFile(filepath, .{ .mode = .read_only });
    defer file.close();

    // creates a 8kB buffer
    var file_buffer: [8192]u8 = undefined;

    // read file in `file_buffer` chunks
    while (true) {
        const n = try file.read(&file_buffer);
        if (n == 0) break; // EOF
        try print("{s}", .{file_buffer[0..n]});
    }
}

pub fn main() !void {
    var debugAlloc: std.heap.DebugAllocator(.{}) = .init;
    const allocator = debugAlloc.allocator();
    defer {
        const deinit_result = debugAlloc.deinit();
        if (deinit_result != .ok) {
            std.debug.print("DebugAllocator deinit error: {any}\n", .{deinit_result});
        }
    }

    const filepath = getFilepathFromArgs(allocator) catch |err| {
        switch (err) {
            ArgsParseError.InvalidArgsLength => {
                std.debug.print("You have to pass exactly one argument to `cat`\n", .{});
                return;
            },
            else => unreachable,
        }
    };

    try readFileAndPrintToStdout(filepath);
}

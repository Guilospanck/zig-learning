const std = @import("std");

pub fn main() !void {
    var buf: [512]u8 = undefined;
    var w = std.fs.File.stdout().writer(&buf);

    var args = std.process.args();
    _ = args.next(); // skip program name

    var first = true;

    while (args.next()) |arg| {
        if (!first) try w.interface.print(" ", .{});

        first = false;
        try w.interface.print("{s}", .{arg});
    }

    try w.interface.print("\n", .{});

    try w.interface.flush();
}

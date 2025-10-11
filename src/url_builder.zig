const std = @import("std");

const URLBuilder = @This();

protocol: []const u8 = "",
domain: []const u8 = "",
port: u32 = 0,

pub const Protocol = enum {
    HTTP,
    HTTPS,

    fn str(self: @This()) []const u8 {
        return switch (self) {
            .HTTP => "http",
            .HTTPS => "https",
        };
    }

    fn defaultPort(self: @This()) u32 {
        return switch (self) {
            .HTTP => 80,
            .HTTPS => 443,
        };
    }
};

pub fn init() @This() {
    return URLBuilder{};
}

pub fn withProtocol(self: *URLBuilder, protocol: Protocol) *URLBuilder {
    self.protocol = protocol.str();
    if (self.port == 0) {
        self.port = protocol.defaultPort();
    }
    return self;
}

pub fn withDomain(self: *URLBuilder, domain: []const u8) *URLBuilder {
    self.domain = domain;
    return self;
}

pub fn withPort(self: *URLBuilder, port: u32) *URLBuilder {
    self.port = port;
    return self;
}

pub fn build(self: *URLBuilder, allocator: std.mem.Allocator) ![]const u8 {
    return try std.fmt.allocPrint(allocator, "{s}://{s}:{d}", .{ self.protocol, self.domain, self.port });
}

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

pub fn withProtocol(self: *@This(), protocol: Protocol) *@This() {
    self.protocol = protocol.str();
    if (self.port == 0) {
        self.port = protocol.defaultPort();
    }
    return self;
}

pub fn withDomain(self: *@This(), domain: []const u8) *@This() {
    self.domain = domain;
    return self;
}

pub fn withPort(self: *@This(), port: u32) *@This() {
    self.port = port;
    return self;
}

pub fn build(self: *@This(), allocator: std.mem.Allocator) ![]const u8 {
    return try std.fmt.allocPrint(allocator, "{s}://{s}:{d}", .{ self.protocol, self.domain, self.port });
}

test "build urls" {
    const allocator = std.testing.allocator;

    var builder = URLBuilder.init();

    const url = try builder.withProtocol(.HTTP).withPort(4444).withDomain("localhost").build(allocator);
    defer allocator.free(url);
    const url2 = try builder.withProtocol(.HTTPS).withPort(3000).withDomain("localhost").build(allocator);
    defer allocator.free(url2);

    try std.testing.expect(std.mem.eql(u8, url, "http://localhost:4444"));
    try std.testing.expect(std.mem.eql(u8, url2, "https://localhost:3000"));
}

test "should use default port" {
    const allocator = std.testing.allocator;

    var builder = URLBuilder.init();
    const url = try builder.withProtocol(.HTTP).withDomain("myinsecuresite.com").build(allocator);
    defer allocator.free(url);

    try std.testing.expect(std.mem.eql(u8, url, "http://myinsecuresite.com:80"));

    var builder2 = URLBuilder.init();
    const url2 = try builder2.withProtocol(.HTTPS).withDomain("mysecuresite.com").build(allocator);
    defer allocator.free(url2);

    try std.testing.expect(std.mem.eql(u8, url2, "https://mysecuresite.com:443"));

    var builder3 = URLBuilder.init();
    const url3 = try builder3.withDomain("mysecuresite.com").withPort(2222).withProtocol(.HTTPS).build(allocator);
    defer allocator.free(url3);

    try std.testing.expect(std.mem.eql(u8, url3, "https://mysecuresite.com:2222"));
}

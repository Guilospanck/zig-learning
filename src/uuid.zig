// ! Implements UUID (https://www.rfc-editor.org/rfc/rfc9562.html)
//
// - 128 bits -> 16 bytes
// - Big endian
//
// DIGIT    = %x30-39 -> (0-9)
// HEXDIG   = DIGIT / "A" / "B" / "C" / "D" / "E" / "F" -> (ABCDEF (also lowercase) and 0-9)
// hexOctet = HEXDIG HEXDIG
// UUID     = 4hexOctet "-"
//            2hexOctet "-"
//            2hexOctet "-"
//            2hexOctet "-"
//            6hexOctet
//
// - Alphabetic chars can be all uppercase, all lowercase or mixed case.
//
// - Example: f81d4fae-7dec-11d0-a765-00a0c91e6bf6
//            11223344-5566-7788-9900-112233445566  octets
//            12345678-9012-3456-7890-123456789012
//                    (40)        (80)      (120)   bits
//            4HOc    -2HOc-2HOc-2HOc- 6HOctet

const std = @import("std");

uuid: [16]u8 = undefined,

const ALLOWED_CHARS = [_]u8{ 'A', 'B', 'C', 'D', 'E', 'F', 'a', 'b', 'c', 'd', 'e', 'f', '0', '1', '2', '3', '4', '5', '6', '7', '8', '9' };
const HYPHEN: u8 = '-';
const HEX_CHARS_LEN: u8 = 32; // 16 bytes turns into 32 hex chars (without counting hyphens)

// Variant Fields (Octet 8)
const NCS_RESERVED_BITMASK: u8 = 0b0000_0000;
const RFC_COMPLIANT: u8 = 0b1000_0000;
const MICROSOFT_RESERVED: u8 = 0b1100_0000;
const FUTURE_RESERVED: u8 = 0b1110_0000;

const UUID = @This();

const Error = error{ HexCharsWrongLength, InvalidChar };

fn removeHyphens(allocator: std.mem.Allocator, input: []const u8) ![]const u8 {
    var list = try std.ArrayList(u8).initCapacity(allocator, input.len);

    for (input) |ch| {
        if (ch == HYPHEN) {
            continue;
        }
        if (std.mem.indexOfScalar(u8, &ALLOWED_CHARS, ch) == null) {
            return Error.InvalidChar;
        }
        try list.append(allocator, ch);
    }

    const response = try list.toOwnedSlice(allocator);

    if (response.len != HEX_CHARS_LEN) {
        return Error.HexCharsWrongLength;
    }

    return response;
}

test "validate variant fields" {
    var debugAlloc: std.heap.DebugAllocator(.{}) = .init;
    const allocator = debugAlloc.allocator();

    const microsoft_reserved = try removeHyphens(allocator, "f81d4fae-7dec-11d0-a765-00a0c91e6bf6");
    defer allocator.free(microsoft_reserved);

    var buf: [16]u8 = undefined;

    _ = try std.fmt.hexToBytes(&buf, microsoft_reserved);

    for (buf) |byte| {
        std.debug.print("0x{x}\n", .{byte});
    }
}

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

const NIL_UUID: [16]u8 = [_]u8{ 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 };
const MAX_UUID: [16]u8 = [_]u8{ 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF };

uuid: [16]u8 = NIL_UUID,

const ALLOWED_CHARS = [_]u8{ 'A', 'B', 'C', 'D', 'E', 'F', 'a', 'b', 'c', 'd', 'e', 'f', '0', '1', '2', '3', '4', '5', '6', '7', '8', '9' };
const HYPHEN: u8 = '-';
const HEX_CHARS_LEN: u8 = 32; // 16 bytes turns into 32 hex chars (without counting hyphens)

// Variant Fields (Octet 8) (https://www.rfc-editor.org/rfc/rfc9562.html#name-variant-field)
const NCS_RESERVED_BITMASK: u8 = 0b0000_0000;
const RFC_COMPLIANT_BITMASK: u8 = 0b1000_0000;
const MICROSOFT_RESERVED_BITMASK: u8 = 0b1100_0000;
const FUTURE_RESERVED_BITMASK: u8 = 0b1110_0000;

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

// https://www.rfc-editor.org/rfc/rfc9562.html#name-variant-field
test "validate variant fields" {
    var debugAlloc: std.heap.DebugAllocator(.{}) = .init;
    const allocator = debugAlloc.allocator();

    const ncs_reserved = try removeHyphens(allocator, "f81d4fae-7dec-110d-a765-00a0c91e6bf6");
    defer allocator.free(ncs_reserved); //                             ^^

    const rfc_compliant = try removeHyphens(allocator, "f81d4fae-7dec-11d0-a765-00a0c91e6bf6");
    defer allocator.free(rfc_compliant); //                             ^^

    const microsoft_reserved = try removeHyphens(allocator, "f81d4fae-7dec-11F0-a765-00a0c91e6bf6");
    defer allocator.free(microsoft_reserved); //                             ^^

    const future_reserved = try removeHyphens(allocator, "f81d4fae-7dec-11FF-a765-00a0c91e6bf6");
    defer allocator.free(future_reserved); //                             ^^

    var buf: [16]u8 = undefined;

    _ = try std.fmt.hexToBytes(&buf, ncs_reserved);
    var eighth_octet = buf[7]; // the eighth octet is where the variant field is defined.
    try std.testing.expect((eighth_octet & NCS_RESERVED_BITMASK) == NCS_RESERVED_BITMASK);

    _ = try std.fmt.hexToBytes(&buf, rfc_compliant);
    eighth_octet = buf[7]; // the eighth octet is where the variant field is defined.
    try std.testing.expect((eighth_octet & RFC_COMPLIANT_BITMASK) == RFC_COMPLIANT_BITMASK);

    _ = try std.fmt.hexToBytes(&buf, microsoft_reserved);
    eighth_octet = buf[7]; // the eighth octet is where the variant field is defined.
    try std.testing.expect((eighth_octet & MICROSOFT_RESERVED_BITMASK) == MICROSOFT_RESERVED_BITMASK);

    _ = try std.fmt.hexToBytes(&buf, future_reserved);
    eighth_octet = buf[7]; // the eighth octet is where the variant field is defined.
    try std.testing.expect((eighth_octet & FUTURE_RESERVED_BITMASK) == FUTURE_RESERVED_BITMASK);

    // for (buf) |byte| {
    //     std.debug.print("{any}: 0x{x}: 0b{b:0>8}\n", .{ byte, byte, byte });
    // }
}

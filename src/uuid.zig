//! Implements UUID v7 (https://www.rfc-editor.org/rfc/rfc9562.html#name-uuid-version-7)
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
//
// This is how the bits are laid out in v7:
//
//  0                   1                   2                   3
//  0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
// +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
// |                           unix_ts_ms                          |
// +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
// |          unix_ts_ms           |  ver  |       rand_a          |
// +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
// |var|                        rand_b                             |
// +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
// |                            rand_b                             |
// +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
//

const std = @import("std");

const NIL_UUID: [16]u8 = [_]u8{ 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 };
const MAX_UUID: [16]u8 = [_]u8{ 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF };

uuid: [16]u8 = NIL_UUID,

const ALLOWED_CHARS = [_]u8{ 'A', 'B', 'C', 'D', 'E', 'F', 'a', 'b', 'c', 'd', 'e', 'f', '0', '1', '2', '3', '4', '5', '6', '7', '8', '9' };
const HYPHEN: u8 = '-';
const HEX_CHARS_LEN: u8 = 32; // 16 bytes turns into 32 hex chars (without counting hyphens)

// Variant Fields (Octet 8) (zero-based index) (https://www.rfc-editor.org/rfc/rfc9562.html#name-variant-field)
const VARIANT_FIELD_NCS_RESERVED_BITMASK: u8 = 0b0000_0000;
const VARIANT_FIELD_RFC_COMPLIANT_BITMASK: u8 = 0b1000_0000;
const VARIANT_FIELD_MICROSOFT_RESERVED_BITMASK: u8 = 0b1100_0000;
const VARIANT_FIELD_FUTURE_RESERVED_BITMASK: u8 = 0b1110_0000;

// Version fields (Octet 6) (zero-based index) (https://www.rfc-editor.org/rfc/rfc9562.html#name-version-field)
const VERSION_FIELD_UNUSED_BITMASK: u8 = 0b0000_0000;
const VERSION_FIELD_V01_BITMASK: u8 = 0b0001_0000;
const VERSION_FIELD_V02_BITMASK: u8 = 0b0010_0000;
const VERSION_FIELD_V03_BITMASK: u8 = 0b0011_0000;
const VERSION_FIELD_V04_BITMASK: u8 = 0b0100_0000;
const VERSION_FIELD_V05_BITMASK: u8 = 0b0101_0000;
const VERSION_FIELD_V06_BITMASK: u8 = 0b0110_0000;
const VERSION_FIELD_V07_BITMASK: u8 = 0b0111_0000;
const VERSION_FIELD_V08_BITMASK: u8 = 0b1000_0000;
const VERSION_FIELD_FUTURE_V09_BITMASK: u8 = 0b1001_0000;
const VERSION_FIELD_FUTURE_V10_BITMASK: u8 = 0b1010_0000;
const VERSION_FIELD_FUTURE_V11_BITMASK: u8 = 0b1011_0000;
const VERSION_FIELD_FUTURE_V12_BITMASK: u8 = 0b1100_0000;
const VERSION_FIELD_FUTURE_V13_BITMASK: u8 = 0b1101_0000;
const VERSION_FIELD_FUTURE_V14_BITMASK: u8 = 0b1110_0000;
const VERSION_FIELD_FUTURE_V15_BITMASK: u8 = 0b1111_0000;

const UUID = @This();

const Error = error{ HexCharsWrongLength, InvalidChar };

/// Function responsible for:
/// - removing hyphens
/// - checking length (MUST be 128 bits)
/// - checking allowed chars
///
fn preprocessUUID(allocator: std.mem.Allocator, input: []const u8) ![]const u8 {
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

    const ncs_reserved = try preprocessUUID(allocator, "f81d4fae-7dec-11a7-0065-00a0c91e6bf6");
    defer allocator.free(ncs_reserved); //                                 ^^

    const rfc_compliant = try preprocessUUID(allocator, "f81d4fae-7dec-11a7-8065-00a0c91e6bf6");
    defer allocator.free(rfc_compliant); //                                 ^^

    const microsoft_reserved = try preprocessUUID(allocator, "f81d4fae-7dec-11a7-C065-00a0c91e6bf6");
    defer allocator.free(microsoft_reserved); //                                 ^^

    const future_reserved = try preprocessUUID(allocator, "f81d4fae-7dec-11a7-F065-00a0c91e6bf6");
    defer allocator.free(future_reserved); //                                 ^^

    var buf: [16]u8 = undefined;

    _ = try std.fmt.hexToBytes(&buf, ncs_reserved);
    var octet_eight = buf[8]; // the octet 8 is where the variant field is defined.
    try std.testing.expect((octet_eight & VARIANT_FIELD_NCS_RESERVED_BITMASK) == VARIANT_FIELD_NCS_RESERVED_BITMASK);

    _ = try std.fmt.hexToBytes(&buf, rfc_compliant);
    octet_eight = buf[8]; // the octet 8 is where the variant field is defined.
    try std.testing.expect((octet_eight & VARIANT_FIELD_RFC_COMPLIANT_BITMASK) == VARIANT_FIELD_RFC_COMPLIANT_BITMASK);

    _ = try std.fmt.hexToBytes(&buf, microsoft_reserved);
    octet_eight = buf[8]; // the octet 8 is where the variant field is defined.
    try std.testing.expect((octet_eight & VARIANT_FIELD_MICROSOFT_RESERVED_BITMASK) == VARIANT_FIELD_MICROSOFT_RESERVED_BITMASK);

    _ = try std.fmt.hexToBytes(&buf, future_reserved);
    octet_eight = buf[8]; // the octet 8 is where the variant field is defined.
    try std.testing.expect((octet_eight & VARIANT_FIELD_FUTURE_RESERVED_BITMASK) == VARIANT_FIELD_FUTURE_RESERVED_BITMASK);

    // for (buf) |byte| {
    //     std.debug.print("{any}: 0x{x}: 0b{b:0>8}\n", .{ byte, byte, byte });
    // }
}

// Note that the version validation is only for UUID of variant RFC_COMPLIANT
// https://www.rfc-editor.org/rfc/rfc9562.html#name-version-field
test "validate version field" {
    // if (true) {
    //     return error.SkipZigTest;
    // }

    var debugAlloc: std.heap.DebugAllocator(.{}) = .init;
    const allocator = debugAlloc.allocator();

    const unused = try preprocessUUID(allocator, "f81d4fae-7dec-00d0-a765-00a0c91e6bf6");
    defer allocator.free(unused); //                            ^^

    const version1 = try preprocessUUID(allocator, "f81d4fae-7dec-10d0-a765-00a0c91e6bf6");
    defer allocator.free(version1); //                            ^^

    const version2 = try preprocessUUID(allocator, "f81d4fae-7dec-20d0-a765-00a0c91e6bf6");
    defer allocator.free(version2); //                            ^^

    const version3 = try preprocessUUID(allocator, "f81d4fae-7dec-30d0-a765-00a0c91e6bf6");
    defer allocator.free(version3); //                            ^^

    const version4 = try preprocessUUID(allocator, "f81d4fae-7dec-40d0-a765-00a0c91e6bf6");
    defer allocator.free(version4); //                            ^^

    const version5 = try preprocessUUID(allocator, "f81d4fae-7dec-50d0-a765-00a0c91e6bf6");
    defer allocator.free(version5); //                            ^^

    const version6 = try preprocessUUID(allocator, "f81d4fae-7dec-60d0-a765-00a0c91e6bf6");
    defer allocator.free(version6); //                            ^^

    const version7 = try preprocessUUID(allocator, "f81d4fae-7dec-70d0-a765-00a0c91e6bf6");
    defer allocator.free(version7); //                            ^^

    const version8 = try preprocessUUID(allocator, "f81d4fae-7dec-80d0-a765-00a0c91e6bf6");
    defer allocator.free(version8); //                            ^^

    const version9 = try preprocessUUID(allocator, "f81d4fae-7dec-90d0-a765-00a0c91e6bf6");
    defer allocator.free(version9); //                            ^^

    const version10 = try preprocessUUID(allocator, "f81d4fae-7dec-A0d0-a765-00a0c91e6bf6");
    defer allocator.free(version10); //                            ^^

    const version11 = try preprocessUUID(allocator, "f81d4fae-7dec-B0d0-a765-00a0c91e6bf6");
    defer allocator.free(version11); //                            ^^

    const version12 = try preprocessUUID(allocator, "f81d4fae-7dec-C0d0-a765-00a0c91e6bf6");
    defer allocator.free(version12); //                            ^^

    const version13 = try preprocessUUID(allocator, "f81d4fae-7dec-D0d0-a765-00a0c91e6bf6");
    defer allocator.free(version13); //                            ^^

    const version14 = try preprocessUUID(allocator, "f81d4fae-7dec-E0d0-a765-00a0c91e6bf6");
    defer allocator.free(version14); //                            ^^

    const version15 = try preprocessUUID(allocator, "f81d4fae-7dec-F0d0-a765-00a0c91e6bf6");
    defer allocator.free(version15); //                            ^^

    var buf: [16]u8 = undefined;

    _ = try std.fmt.hexToBytes(&buf, unused);
    var octet_six = buf[6]; // the octet six is where the version field is defined.
    try std.testing.expect((octet_six & VERSION_FIELD_UNUSED_BITMASK) == VERSION_FIELD_UNUSED_BITMASK);

    _ = try std.fmt.hexToBytes(&buf, version1);
    octet_six = buf[6]; // the octet six is where the version field is defined.
    try std.testing.expect((octet_six & VERSION_FIELD_V01_BITMASK) == VERSION_FIELD_V01_BITMASK);

    _ = try std.fmt.hexToBytes(&buf, version2);
    octet_six = buf[6]; // the octet six is where the version field is defined.
    try std.testing.expect((octet_six & VERSION_FIELD_V02_BITMASK) == VERSION_FIELD_V02_BITMASK);

    _ = try std.fmt.hexToBytes(&buf, version3);
    octet_six = buf[6]; // the octet six is where the version field is defined.
    try std.testing.expect((octet_six & VERSION_FIELD_V03_BITMASK) == VERSION_FIELD_V03_BITMASK);

    _ = try std.fmt.hexToBytes(&buf, version4);
    octet_six = buf[6]; // the octet six is where the version field is defined.
    try std.testing.expect((octet_six & VERSION_FIELD_V04_BITMASK) == VERSION_FIELD_V04_BITMASK);

    _ = try std.fmt.hexToBytes(&buf, version5);
    octet_six = buf[6]; // the octet six is where the version field is defined.
    try std.testing.expect((octet_six & VERSION_FIELD_V05_BITMASK) == VERSION_FIELD_V05_BITMASK);

    _ = try std.fmt.hexToBytes(&buf, version6);
    octet_six = buf[6]; // the octet six is where the version field is defined.
    try std.testing.expect((octet_six & VERSION_FIELD_V06_BITMASK) == VERSION_FIELD_V06_BITMASK);

    _ = try std.fmt.hexToBytes(&buf, version7);
    octet_six = buf[6]; // the octet six is where the version field is defined.
    try std.testing.expect((octet_six & VERSION_FIELD_V07_BITMASK) == VERSION_FIELD_V07_BITMASK);

    _ = try std.fmt.hexToBytes(&buf, version8);
    octet_six = buf[6]; // the octet six is where the version field is defined.
    try std.testing.expect((octet_six & VERSION_FIELD_V08_BITMASK) == VERSION_FIELD_V08_BITMASK);

    _ = try std.fmt.hexToBytes(&buf, version9);
    octet_six = buf[6]; // the octet six is where the version field is defined.
    try std.testing.expect((octet_six & VERSION_FIELD_FUTURE_V09_BITMASK) == VERSION_FIELD_FUTURE_V09_BITMASK);

    _ = try std.fmt.hexToBytes(&buf, version10);
    octet_six = buf[6]; // the octet six is where the version field is defined.
    try std.testing.expect((octet_six & VERSION_FIELD_FUTURE_V10_BITMASK) == VERSION_FIELD_FUTURE_V10_BITMASK);

    _ = try std.fmt.hexToBytes(&buf, version11);
    octet_six = buf[6]; // the octet six is where the version field is defined.
    try std.testing.expect((octet_six & VERSION_FIELD_FUTURE_V11_BITMASK) == VERSION_FIELD_FUTURE_V11_BITMASK);

    _ = try std.fmt.hexToBytes(&buf, version12);
    octet_six = buf[6]; // the octet six is where the version field is defined.
    try std.testing.expect((octet_six & VERSION_FIELD_FUTURE_V12_BITMASK) == VERSION_FIELD_FUTURE_V12_BITMASK);

    _ = try std.fmt.hexToBytes(&buf, version13);
    octet_six = buf[6]; // the octet six is where the version field is defined.
    try std.testing.expect((octet_six & VERSION_FIELD_FUTURE_V13_BITMASK) == VERSION_FIELD_FUTURE_V13_BITMASK);

    _ = try std.fmt.hexToBytes(&buf, version14);
    octet_six = buf[6]; // the octet six is where the version field is defined.
    try std.testing.expect((octet_six & VERSION_FIELD_FUTURE_V14_BITMASK) == VERSION_FIELD_FUTURE_V14_BITMASK);

    _ = try std.fmt.hexToBytes(&buf, version15);
    octet_six = buf[6]; // the octet six is where the version field is defined.
    try std.testing.expect((octet_six & VERSION_FIELD_FUTURE_V15_BITMASK) == VERSION_FIELD_FUTURE_V15_BITMASK);
}

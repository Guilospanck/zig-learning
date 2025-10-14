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
//
const std = @import("std");

const NIL_UUID: [16]u8 = [_]u8{ 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 };
const MAX_UUID: [16]u8 = [_]u8{ 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF };

uuid: [16]u8 = NIL_UUID,

const ALLOWED_CHARS = [_]u8{ 'A', 'B', 'C', 'D', 'E', 'F', 'a', 'b', 'c', 'd', 'e', 'f', '0', '1', '2', '3', '4', '5', '6', '7', '8', '9' }; // only hexadecimal allowed
const HYPHEN: u8 = '-';
const HEX_CHARS_LEN: u8 = 32; // 16 bytes turns into 32 hex chars (without counting hyphens)
const HEX_CHARS_PLUS_HYPHEN_LEN: u8 = 36;

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

const Error = error{ HexCharsWrongLength, InvalidChar, InvalidTimestamp };

/// Function responsible for:
/// - removing hyphens
/// - checking length (MUST be 128 bits)
/// - checking allowed chars
///
/// Errors:
/// - `InvalidChar` if any non-hexadecimal char in the UUID;
/// - `HexCharsWrongLength` if after removing hyphens, the length doesn't match
/// `HEX_CHARS_LEN`.
/// - Other erros related to std.ArrayList.
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

/// Gets 'NBytes' bytes in Big Endian format of an input.
///
///
// An easy way of understanding this function is thinking about it as if
// you were looking through a window and seeing a limousine with many doors.
//
//                        ____________________________________________________
//     Front of limousine |  [[0]] [[1]] [[2]] [[3]] [[4]] [[5]] [[6]] [[7]] | back of limousine
//                        |                                                  |
//                        |_O______________________________________________O_|
//
//                                 >> shift direction
//                                                                     ______
//                                                                     |0xFF| your window
//                                                                     ______
//
//
// The size of the window (how much you can see) is determined by 0xFF, which
// means "I want to see only the LSB - Least Significant Byte" (so you can only see one byte (door) per time).
//
// The limousine (`input`) has `@bitSizeOf(InputType) / 8` doors.
// So, for example, for a InputType of u64, it would have 8 doors.
//
// At each loop, we show inside the window only one door.
// We do that by using the `shift`. Think of the shift as the
// limousine driving in reverse.
//
// Because we're saving the bytes in Big Endian, we shift as much as we can (NBytes - 1)
// the first time to the RIGHT to show the first door we want (the NBytes door).
// In our example, if NBytes is 3 (meaning we only want the first 3 LSBs of our input),
// then the first door we're gonna see through the window is the byte 5.
//
// Then, in the next loops, we start from scratch (the position of the limousine
// resets), and then we shift just a byte less (one door less) than the
// iteration before. We do it until the last door is shown inside the window.
//
//
// EXAMPLE: NBytes (the amount of bytes in our result that we want) is 3 and
// our limousine is u64 => therefore 8 bytes = 8 doors.
//
// First loop: records byte 5
//    - shift is: NBytes - 1 - index = 3 - 1 - 0 = 2: move 2 bytes to the right
//
//                                                                          |
//                                    ______________________________________|______________
//                 Front of limousine |  [[0]] [[1]] [[2]] [[3]] [[4]] [[5]]| [[6]] [[7]] | back of limousine
//                                    |                                     |             |
//                                    |_O___________________________________|___________O_|
//                                                                          |
//                                                                          |
//                             >> shift direction
//                                                                    ______
//                                                                    |0xFF| your window
//                                                                    ______
//
// Second loop: records byte 6
//    - shift is: NBytes - 1 - index = 3 - 1 - 1 = 1: move 1 byte to the right
//
//                                                                          |
//                              ____________________________________________|________
//           Front of limousine |  [[0]] [[1]] [[2]] [[3]] [[4]] [[5]] [[6]]| [[7]] | back of limousine
//                              |                                           |       |
//                              |_O_________________________________________|_____O_|
//                                                                          |
//                                                                          |
//                             >> shift direction
//                                                                    ______
//                                                                    |0xFF| your window
//                                                                    ______
//
// Third loop: records byte 7
//    - shift is: NBytes - 1 - index = 3 - 1 - 2 = 0: move 0 byte to the right
//
//
//                       ___________________________________________________|
//    Front of limousine |  [[0]] [[1]] [[2]] [[3]] [[4]] [[5]] [[6]] [[7]] | back of limousine
//                       |                                                  |
//                       |_O______________________________________________O_|
//                                                                          |
//
//
//                             >> shift direction
//                                                                    ______
//                                                                    |0xFF| your window
//                                                                    ______
//
//
fn toBEBytes(comptime InputType: type, comptime NBytes: comptime_int, input: InputType) [NBytes]u8 {
    var out: [NBytes]u8 = undefined;

    const total_bits: comptime_int = @bitSizeOf(InputType);
    const total_bytes: comptime_int = total_bits / 8;

    comptime {
        if (@typeInfo(InputType) != .int)
            @compileError("InputType must be an Int");
        if (NBytes <= 0)
            @compileError("NBytes must be > 0");
        if (NBytes > total_bytes)
            @compileError("NBytes must be ≤ total_bytes");
    }

    // We need the Shift type to be log2 (compiler requires)
    const ShiftType = std.math.Log2Int(InputType);

    for (0..NBytes) |i| {
        const index: ShiftType = @intCast(i);
        // we only get starting from the NBytes byte, which effectively discards
        // the MSB of `InputType` if `NBytes` is less than `total_bytes`,
        const shift = (NBytes - 1 - index) * 8;
        const value: u8 = @intCast((input >> shift) & 0xFF);
        out[i] = value;
    }

    return out;
}

/// Creates UUID version 7.
///
// - 48 bits (6 bytes): Unix timestamp milliseconds
// - 4 bits: version set to 0b0111 (7)
// - 12 bits: random data
// - 2 bits: variant set to 0b10 (RFC_COMPLIANT)
// - 62 bits: random data
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
pub fn v7(allocator: std.mem.Allocator) ![]const u8 {
    // timestamp
    const unix_ms_signed_int: i64 = std.time.milliTimestamp();
    if (unix_ms_signed_int < 0) {
        return Error.InvalidTimestamp;
    }
    const unix_ts_ms: u64 = @intCast(unix_ms_signed_int);
    const first_48bytes_unix_ts: [6]u8 = toBEBytes(u64, 6, unix_ts_ms);
    var unix_48bits: u48 = 0;
    for (first_48bytes_unix_ts) |byte| {
        unix_48bits = (unix_48bits << 8) | @as(u48, byte);
    }

    // version (7)
    const version: u4 = 0b0111;

    const rand = std.crypto.random;

    // random data (a)
    const random_data_a: u12 = rand.int(u12);

    // variant (RFC_COMPLIANT)
    const variant: u2 = 0b10;

    // random data (b)
    const random_data_b: u62 = rand.int(u62);

    var uuid_v7: u128 = 0;
    uuid_v7 = (uuid_v7 << 48) | @as(u128, unix_48bits);
    uuid_v7 = (uuid_v7 << 4) | @as(u128, version);
    uuid_v7 = (uuid_v7 << 12) | @as(u128, random_data_a);
    uuid_v7 = (uuid_v7 << 2) | @as(u128, variant);
    uuid_v7 = (uuid_v7 << 62) | @as(u128, random_data_b);

    // std.debug.print("0x{x:0>32}\n: 0b{b:0>128}\n", .{ uuid_v7, uuid_v7 });

    var list = try std.ArrayList(u8).initCapacity(allocator, HEX_CHARS_PLUS_HYPHEN_LEN);

    const bytes: [16]u8 = toBEBytes(u128, 16, uuid_v7); // const bytes: [16]u8 = @bitCast(uuid_v7);

    for (bytes, 0..) |byte, i| {
        const hex = try std.fmt.allocPrint(allocator, "{x:0>2}", .{byte});
        defer allocator.free(hex);

        try list.appendSlice(allocator, hex);
        if (i == 3 or i == 5 or i == 7 or i == 9) {
            try list.append(allocator, HYPHEN);
        }
    }

    return try list.toOwnedSlice(allocator);
}

test "uuid version 7" {
    var debugAlloc: std.heap.DebugAllocator(.{}) = .init;
    const allocator = debugAlloc.allocator();

    const uuid = try v7(allocator);
    defer allocator.free(uuid);

    // preprocess result
    const processed_uuid = try preprocessUUID(allocator, uuid);

    // by here we have a uuid that at least has the valid characters and valid length.
    var uuid_bytes: [16]u8 = undefined;
    _ = try std.fmt.hexToBytes(&uuid_bytes, processed_uuid);

    // Validate octet 8 for the variant field (should be RFC_COMPLIANT)
    try std.testing.expect((uuid_bytes[8] & VARIANT_FIELD_RFC_COMPLIANT_BITMASK) == VARIANT_FIELD_RFC_COMPLIANT_BITMASK);

    // Validate octet 6 for the version field (should be 7: 0b0111)
    try std.testing.expect((uuid_bytes[6] & VERSION_FIELD_V07_BITMASK) == VERSION_FIELD_V07_BITMASK);
}

// https://www.rfc-editor.org/rfc/rfc9562.html#name-variant-field
test "validate variant fields" {
    var debugAlloc: std.heap.DebugAllocator(.{}) = .init;
    const allocator = debugAlloc.allocator();

    const VariantTest = struct { raw_uuid: []const u8, bitmask_test: u8 };

    var list = try std.ArrayList(VariantTest).initCapacity(allocator, @sizeOf(VariantTest) * 4);
    defer list.deinit(allocator);

    try list.append(allocator, .{ .raw_uuid = "f81d4fae-7dec-11a7-0065-00a0c91e6bf6", .bitmask_test = VARIANT_FIELD_NCS_RESERVED_BITMASK });
    //                                                        ^^
    try list.append(allocator, .{ .raw_uuid = "f81d4fae-7dec-11a7-8065-00a0c91e6bf6", .bitmask_test = VARIANT_FIELD_RFC_COMPLIANT_BITMASK });
    //                                                        ^^
    try list.append(allocator, .{ .raw_uuid = "f81d4fae-7dec-11a7-C065-00a0c91e6bf6", .bitmask_test = VARIANT_FIELD_MICROSOFT_RESERVED_BITMASK });
    //                                                        ^^
    try list.append(allocator, .{ .raw_uuid = "f81d4fae-7dec-11a7-F065-00a0c91e6bf6", .bitmask_test = VARIANT_FIELD_FUTURE_RESERVED_BITMASK });
    //                                                        ^^

    for (list.items) |item| {
        const uuid_processed = try preprocessUUID(allocator, item.raw_uuid);
        defer allocator.free(uuid_processed);

        var buf: [16]u8 = undefined;
        _ = try std.fmt.hexToBytes(&buf, uuid_processed);

        // Tests the octet 8, where the variant field exists
        try std.testing.expect((buf[8] & item.bitmask_test) == item.bitmask_test);
    }

    // for (buf) |byte| {
    //     std.debug.print("{any}: 0x{x}: 0b{b:0>8}\n", .{ byte, byte, byte });
    // }
}

// Note that the version validation is only for UUID of variant RFC_COMPLIANT
// https://www.rfc-editor.org/rfc/rfc9562.html#name-version-field
test "validate version field" {
    // INFO: this is how you skip a test in Zig.
    // if (true) {
    //     return error.SkipZigTest;
    // }

    var debugAlloc: std.heap.DebugAllocator(.{}) = .init;
    const allocator = debugAlloc.allocator();

    const VersionTest = struct {
        raw_uuid: []const u8,
        bitmask_test: u8,
    };

    var list = try std.ArrayList(VersionTest).initCapacity(allocator, @sizeOf(VersionTest) * 16);
    defer list.deinit(allocator);

    try list.append(allocator, .{ .raw_uuid = "f81d4fae-7dec-00d0-a765-00a0c91e6bf6", .bitmask_test = VERSION_FIELD_UNUSED_BITMASK });
    //                                                       ^^
    try list.append(allocator, .{ .raw_uuid = "f81d4fae-7dec-10d0-a765-00a0c91e6bf6", .bitmask_test = VERSION_FIELD_V01_BITMASK });
    //                                                       ^^
    try list.append(allocator, .{ .raw_uuid = "f81d4fae-7dec-20d0-a765-00a0c91e6bf6", .bitmask_test = VERSION_FIELD_V02_BITMASK });
    //                                                       ^^
    try list.append(allocator, .{ .raw_uuid = "f81d4fae-7dec-30d0-a765-00a0c91e6bf6", .bitmask_test = VERSION_FIELD_V03_BITMASK });
    //                                                       ^^
    try list.append(allocator, .{ .raw_uuid = "f81d4fae-7dec-40d0-a765-00a0c91e6bf6", .bitmask_test = VERSION_FIELD_V04_BITMASK });
    //                                                       ^^
    try list.append(allocator, .{ .raw_uuid = "f81d4fae-7dec-50d0-a765-00a0c91e6bf6", .bitmask_test = VERSION_FIELD_V05_BITMASK });
    //                                                       ^^
    try list.append(allocator, .{ .raw_uuid = "f81d4fae-7dec-60d0-a765-00a0c91e6bf6", .bitmask_test = VERSION_FIELD_V06_BITMASK });
    //                                                       ^^
    try list.append(allocator, .{ .raw_uuid = "f81d4fae-7dec-70d0-a765-00a0c91e6bf6", .bitmask_test = VERSION_FIELD_V07_BITMASK });
    //                                                       ^^
    try list.append(allocator, .{ .raw_uuid = "f81d4fae-7dec-80d0-a765-00a0c91e6bf6", .bitmask_test = VERSION_FIELD_V08_BITMASK });
    //                                                       ^^
    try list.append(allocator, .{ .raw_uuid = "f81d4fae-7dec-90d0-a765-00a0c91e6bf6", .bitmask_test = VERSION_FIELD_FUTURE_V09_BITMASK });
    //                                                       ^^
    try list.append(allocator, .{ .raw_uuid = "f81d4fae-7dec-A0d0-a765-00a0c91e6bf6", .bitmask_test = VERSION_FIELD_FUTURE_V10_BITMASK });
    //                                                       ^^
    try list.append(allocator, .{ .raw_uuid = "f81d4fae-7dec-B0d0-a765-00a0c91e6bf6", .bitmask_test = VERSION_FIELD_FUTURE_V11_BITMASK });
    //                                                       ^^
    try list.append(allocator, .{ .raw_uuid = "f81d4fae-7dec-C0d0-a765-00a0c91e6bf6", .bitmask_test = VERSION_FIELD_FUTURE_V12_BITMASK });
    //                                                       ^^
    try list.append(allocator, .{ .raw_uuid = "f81d4fae-7dec-D0d0-a765-00a0c91e6bf6", .bitmask_test = VERSION_FIELD_FUTURE_V13_BITMASK });
    //                                                       ^^
    try list.append(allocator, .{ .raw_uuid = "f81d4fae-7dec-E0d0-a765-00a0c91e6bf6", .bitmask_test = VERSION_FIELD_FUTURE_V14_BITMASK });
    //                                                       ^^
    try list.append(allocator, .{ .raw_uuid = "f81d4fae-7dec-F0d0-a765-00a0c91e6bf6", .bitmask_test = VERSION_FIELD_FUTURE_V15_BITMASK });
    //                                                       ^^

    for (list.items) |item| {
        const uuid_processed = try preprocessUUID(allocator, item.raw_uuid);
        defer allocator.free(uuid_processed);

        var buf: [16]u8 = undefined;
        _ = try std.fmt.hexToBytes(&buf, uuid_processed);

        try std.testing.expect((buf[6] & item.bitmask_test) == item.bitmask_test);
    }
}

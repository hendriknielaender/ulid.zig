const std = @import("std");
const Ulid = @import("ulid").Ulid;
const UlidError = Ulid.UlidError;
const UlidGenerator = Ulid.UlidGenerator;

pub fn main() !void {
    // Generate a new ULID
    const ulid = try Ulid.generate();
    var encoded_ulid: [26]u8 = undefined;
    try ulid.encode(&encoded_ulid);
    std.debug.print("Generated ULID: {s}\n", .{encoded_ulid});

    // Decode the ULID back to its components
    var decoded_ulid: Ulid = undefined;
    try Ulid.decode(encoded_ulid[0..], &decoded_ulid);
    std.debug.print("Decoded ULID Timestamp: {}\n", .{decoded_ulid.timestamp});
    std.debug.print("Decoded ULID Randomness: {any}\n", .{decoded_ulid.randomness});
}

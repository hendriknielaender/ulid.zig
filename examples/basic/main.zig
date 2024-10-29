const std = @import("std");
const Ulid = @import("ulid").Ulid;
const UlidError = Ulid.UlidError;
const UlidGenerator = Ulid.UlidGenerator;

pub fn main() !void {
    // Generate a new ULID
    const ulid = try Ulid.generate();
    std.debug.print("Generated ULID: {s}\n", .{ulid});

    // Decode the ULID back to its components
    var decoded_ulid: Ulid = undefined;
    try Ulid.decode(ulid[0..], &decoded_ulid);
    std.debug.print("Decoded ULID Timestamp: {}\n", .{decoded_ulid.timestamp});
    std.debug.print("Decoded ULID Randomness: {any}\n", .{decoded_ulid.randomness});
}

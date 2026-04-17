const std = @import("std");
const Ulid = @import("ulid").Ulid;

pub fn main(init: std.process.Init) !void {
    const ulid = try Ulid.generate(init.io);
    std.debug.print("Generated ULID: {s}\n", .{ulid});

    var decoded_ulid: Ulid = undefined;
    try Ulid.decode(ulid[0..], &decoded_ulid);
    std.debug.print("Decoded ULID Timestamp: {}\n", .{decoded_ulid.timestamp_ms});
    std.debug.print("Decoded ULID Randomness: {any}\n", .{decoded_ulid.randomness});
}

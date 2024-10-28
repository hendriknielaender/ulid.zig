const std = @import("std");
const crypto = std.crypto;

pub const UlidError = error{
    invalid_length,
    invalid_character,
    overflow,
    encode_error,
    decode_error,
};

pub const Ulid = struct {
    timestamp: u64, // 48 bits used
    randomness: [10]u8, // 80 bits

    /// Precomputed Crockford's Base32 encoding table
    const BASE32_TABLE = "0123456789ABCDEFGHJKMNPQRSTVWXYZ";

    /// Precomputed Base32 decoding map
    pub const DECODE_MAP: [256]u8 = Ulid.init_decode_map();

    /// Initializes the Base32 decoding map at compile time.
    fn init_decode_map() [256]u8 {
        var map: [256]u8 = undefined;
        // Initialize all entries to 0xFF (invalid)
        for (map, 0..) |_, idx| {
            map[idx] = 0xFF;
        }
        // Populate valid characters
        for (Ulid.BASE32_TABLE, 0..) |c, idx| {
            map[c] = @intCast(idx);
            // Map lowercase to uppercase
            if (c >= 'A' and c <= 'Z') {
                map[c + 0x20] = @intCast(idx);
            }
        }
        return map;
    }

    /// Encodes the ULID into a 26-character Crockford's Base32 string.
    pub fn encode(self: Ulid, buffer: []u8) !void {
        // Assert buffer length
        if (buffer.len != 26) return UlidError.encode_error;

        // Combine timestamp and randomness into a 128-bit number
        const time: u128 = @intCast(self.timestamp & 0xFFFFFFFFFFFF);
        var ulid_num: u128 = (time << 80);

        // Combine randomness into the lower 80 bits
        for (self.randomness, 0..) |byte, i| {
            const shift: u7 = @intCast(72 - (i * 8));
            const byte_u128: u128 = @intCast(byte);
            ulid_num |= byte_u128 << shift;
        }

        // Encode into 26 Base32 characters
        inline for (26, 0..) |_, i| {
            const shift = 125 - (i * 5);
            const index: u8 = @intCast((ulid_num >> shift) & 0x1F);
            buffer[i] = Ulid.BASE32_TABLE[index];
        }
    }

    /// Decodes a ULID from a 26-character Crockford's Base32 string.
    pub fn decode(input: []const u8, out: *Ulid) !void {
        // Assert input length
        if (input.len != 26) return UlidError.invalid_length;

        var ulid_num: u128 = 0;

        // Decode each character
        inline for (26, 0..) |_, i| {
            const c = input[i];
            const val = Ulid.DECODE_MAP[c];
            if (val == 0xFF) return UlidError.invalid_character;
            ulid_num = (ulid_num << 5) | @as(u128, val);
        }

        // Extract timestamp
        out.*.timestamp = @intCast((ulid_num >> 80) & 0xFFFFFFFFFFFF);

        // Extract randomness
        inline for (10, 0..) |_, i| {
            out.*.randomness[i] = @intCast((ulid_num >> (72 - (i * 8))) & 0xFF);
        }
    }

    /// Generates a new ULID.
    pub fn generate() !Ulid {
        return Ulid{
            .timestamp = try get_current_timestamp(),
            .randomness = generate_randomness(),
        };
    }

    /// Ensures monotonicity by incrementing randomness if generated within the same millisecond.
    pub fn monotonic_factory() UlidGenerator {
        return UlidGenerator{
            .last_timestamp = 0,
            .last_randomness = undefined,
        };
    }
};

pub const UlidGenerator = struct {
    last_timestamp: u64 = 0,
    last_randomness: [10]u8 = undefined,

    /// Generates a ULID ensuring monotonicity within the same millisecond.
    pub fn generate(self: *UlidGenerator, provided_timestamp: ?u64) !Ulid {
        const current_timestamp = if (provided_timestamp) |ts| ts else try get_current_timestamp();
        var ulid: Ulid = undefined;

        std.debug.print("Current timestamp: {}\n", .{current_timestamp});
        std.debug.print("Last timestamp: {}\n", .{self.last_timestamp});

        if (current_timestamp == self.last_timestamp) {
            std.debug.print("Same millisecond detected. Checking randomness for overflow.\n", .{});

            // Check if all bytes in randomness are 0xFF (indicating overflow)
            var all_max = true;
            for (self.last_randomness) |byte| {
                if (byte != 0xFF) {
                    all_max = false;
                    break;
                }
            }
            if (all_max) {
                std.debug.print("Randomness overflow detected. Returning overflow error.\n", .{});
                return UlidError.overflow;
            }

            // Increment randomness with carry using a for loop
            std.debug.print("Incrementing randomness with carry.\n", .{});
            var carry: bool = true;

            // Iterate from the last index (9) down to 0
            for (0..10) |j| {
                const i = 9 - j; // Calculate the current index
                const new_value = self.last_randomness[i] + 1;
                self.last_randomness[i] = new_value;
                carry = (new_value == 0);

                std.debug.print("Randomness at index {d}: {d}\n", .{ i, new_value });

                if (!carry) break; // No carry needed, exit early
            }

            if (carry) {
                // If carry is still true after the loop, it means all bytes were 0xFF
                std.debug.print("Randomness overflow detected after loop.\n", .{});
                return UlidError.overflow;
            }

            ulid = Ulid{
                .timestamp = current_timestamp,
                .randomness = self.last_randomness,
            };
            std.debug.print("Generated ULID (same millisecond): timestamp={d}, randomness={d}\n", .{ ulid.timestamp, ulid.randomness });
        } else {
            // Generate a new ULID with a fresh randomness value
            ulid = Ulid{
                .timestamp = current_timestamp,
                .randomness = generate_randomness(),
            };
            self.last_randomness = ulid.randomness;
            self.last_timestamp = current_timestamp;

            std.debug.print("Generated new ULID (new timestamp): timestamp={d}, randomness={d}\n", .{ ulid.timestamp, ulid.randomness });
        }

        return ulid;
    }
};

fn get_current_timestamp() !u64 {
    const time_ms: u64 = @intCast(std.time.milliTimestamp());
    if (time_ms > 0xFFFFFFFFFFFF) return UlidError.overflow;
    return time_ms;
}

fn generate_randomness() [10]u8 {
    var randomness: [10]u8 = undefined;
    crypto.random.bytes(randomness[0..]);
    return randomness;
}

test "ULID generation produces valid timestamp and randomness" {
    const generated_ulid = try Ulid.generate();

    // Verify timestamp is within 48 bits.
    try std.testing.expect(generated_ulid.timestamp <= 0xFFFFFFFFFFFF);

    // Verify randomness is 10 bytes.
    try std.testing.expect(generated_ulid.randomness[0..].len == 10);
}

test "ULID encoding produces a 26-character Base32 string" {
    var buffer: [26]u8 = undefined;
    const generated_ulid = try Ulid.generate();
    try generated_ulid.encode(&buffer);

    // Verify buffer length
    try std.testing.expect(buffer.len == 26);

    // Verify all characters are valid Base32 characters.
    const base32 = Ulid.BASE32_TABLE;
    for (buffer, 0..) |char, idx| {
        var valid = false;
        for (base32) |c| {
            if (char == c) {
                valid = true;
                break;
            }
        }
        if (!valid) {
            std.debug.print("Invalid character found at index {}: {}\n", .{ idx, char });
        }
        try std.testing.expect(valid);
    }
}

test "ULID decoding correctly parses a valid Base32 string" {
    var buffer: [26]u8 = undefined;
    const ulid = try Ulid.generate();
    try ulid.encode(buffer[0..]);

    var decoded_ulid: Ulid = undefined; // Properly initialize Ulid
    try Ulid.decode(buffer[0..], &decoded_ulid);

    // Verify that the decoded ULID matches the original
    try std.testing.expect(decoded_ulid.timestamp == ulid.timestamp);
    // try std.testing.expect(std.mem.eql(u8, &decoded_ulid.randomness, &ulid.randomness));
    try std.testing.expect(std.mem.eql(u8, decoded_ulid.randomness[0..], ulid.randomness[0..]));
}

test "ULID decoding fails on invalid length" {
    var buffer: [25]u8 = undefined; // Invalid length
    var dummy_ulid: Ulid = undefined; // Properly initialize Ulid
    const result = Ulid.decode(buffer[0..], &dummy_ulid);
    try std.testing.expect(result == UlidError.invalid_length);
}

test "ULID decoding fails on invalid characters" {
    var buffer: [26]u8 = undefined;
    // Populate with valid characters
    for (buffer, 0..) |_, i| buffer[i] = Ulid.BASE32_TABLE[i % 32];
    // Introduce an invalid character
    buffer[10] = '@';
    var dummy_ulid: Ulid = undefined; // Properly initialize Ulid
    const result = Ulid.decode(buffer[0..], &dummy_ulid);
    try std.testing.expect(result == UlidError.invalid_character);
}

test "Monotonic ULID generator increments randomness correctly" {
    var generator = Ulid.monotonic_factory();
    const timestamp = 1234567890123;

    // Generate the first ULID
    const ulid1 = Ulid{
        .timestamp = timestamp,
        .randomness = [10]u8{ 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 },
    };
    generator.last_timestamp = timestamp;
    generator.last_randomness = ulid1.randomness;

    // Generate the second ULID with the same timestamp
    var ulid2 = try generator.generate(timestamp);

    // Expect randomness to be ulid1.randomness + 1
    var expected_randomness = ulid1.randomness;
    expected_randomness[9] += 1;
    try std.testing.expect(std.mem.eql(u8, ulid2.randomness[0..], expected_randomness[0..]));
}

test "Monotonic ULID generator handles overflow correctly" {
    var generator = Ulid.monotonic_factory();
    const timestamp = 1234567890123;

    // Set the last randomness to the maximum value
    generator.last_timestamp = timestamp;
    generator.last_randomness = [10]u8{ 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF };

    // Attempt to generate another ULID within the same millisecond, expecting overflow
    const result = generator.generate(timestamp);
    try std.testing.expect(result == UlidError.overflow);
}

test "Timestamp fits within 48 bits" {
    const ulid = try Ulid.generate();
    try std.testing.expect(ulid.timestamp <= 0xFFFFFFFFFFFF);
}

test "Generated ULID has canonical string representation format" {
    var buffer: [26]u8 = undefined;
    const ulid = try Ulid.generate();
    try ulid.encode(&buffer);

    // Verify timestamp (first 10 chars) and randomness (last 16 chars) format
    const timestamp_part = buffer[0..10];
    const randomness_part = buffer[10..];

    // Ensure the length of each part
    try std.testing.expect(timestamp_part.len == 10);
    try std.testing.expect(randomness_part.len == 16);
}

test "Lexicographical order of ULIDs in the same millisecond" {
    var generator = Ulid.monotonic_factory();
    const timestamp = 1234567890123;

    // Generate ULIDs within the same millisecond
    const ulid1 = try generator.generate(timestamp);
    const ulid2 = try generator.generate(timestamp);
    const ulid3 = try generator.generate(timestamp);

    // Encode ULIDs to verify order
    var buffer1: [26]u8 = undefined;
    var buffer2: [26]u8 = undefined;
    var buffer3: [26]u8 = undefined;
    try ulid1.encode(&buffer1);
    try ulid2.encode(&buffer2);
    try ulid3.encode(&buffer3);

    // Verify lexicographical order using std.mem.lessThan
    try std.testing.expect(std.mem.lessThan(u8, buffer1[0..], buffer2[0..]));
    try std.testing.expect(std.mem.lessThan(u8, buffer2[0..], buffer3[0..]));
}

test "Maximum valid ULID encoding check" {
    var max_ulid = Ulid{
        .timestamp = 0xFFFFFFFFFFFF, // Max 48-bit timestamp
        .randomness = [10]u8{ 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF },
    };

    var buffer: [26]u8 = undefined;
    try max_ulid.encode(&buffer);

    // Verify encoded result does not overflow 128 bits and fits ULID format
    try std.testing.expect(buffer.len == 26);
    try std.testing.expect(buffer[0] != 0); // Check no leading zero-byte
}

test "ULID characters comply with Base32 alphabet" {
    const ulid = try Ulid.generate();
    var buffer: [26]u8 = undefined;
    try ulid.encode(&buffer);

    const base32_alphabet = Ulid.BASE32_TABLE;

    // Verify all characters are in Crockford's Base32 alphabet
    for (buffer, 0..) |char, idx| {
        var valid = false;
        for (base32_alphabet) |base32_char| {
            if (char == base32_char) {
                valid = true;
                break;
            }
        }
        if (!valid) {
            std.debug.print("Invalid Base32 character at index {}: {}\n", .{ idx, char });
        }
        try std.testing.expect(valid);
    }
}

test "ULID decoding succeeds with lowercase characters" {
    var buffer: [26]u8 = undefined;
    const ulid = try Ulid.generate();
    try ulid.encode(buffer[0..]);

    // Convert some characters to lowercase
    buffer[5] = std.ascii.toLower(buffer[5]);
    buffer[15] = std.ascii.toLower(buffer[15]);

    var decoded_ulid: Ulid = undefined;
    try Ulid.decode(buffer[0..], &decoded_ulid);

    // Verify that the decoded ULID matches the original
    try std.testing.expect(decoded_ulid.timestamp == ulid.timestamp);
    try std.testing.expect(std.mem.eql(u8, decoded_ulid.randomness[0..], ulid.randomness[0..]));
}

test "ULID encoding fails with invalid buffer length" {
    var buffer: [25]u8 = undefined; // Invalid length
    const ulid = try Ulid.generate();
    const result = ulid.encode(&buffer);
    try std.testing.expect(result == UlidError.encode_error);
}
//
// test "Monotonic ULID generator correctly handles multiple byte increments with carry" {
//     var generator = Ulid.monotonic_factory();
//     const timestamp = 1234567890123;
//
//     // Set the last two bytes to their maximum values minus one
//     generator.last_timestamp = timestamp;
//     generator.last_randomness = [10]u8{ 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xFF, 0xFE };
//
//     // Generate the first ULID (should increment the last byte)
//     const ulid1 = try generator.generate(timestamp);
//     var expected_randomness1 = generator.last_randomness;
//     expected_randomness1[9] = 0xFF;
//     try std.testing.expect(std.mem.eql(u8, ulid1.randomness[0..], expected_randomness1[0..]));
//
//     // Generate the second ULID (should carry over to the second last byte)
//     const ulid2 = try generator.generate(timestamp);
//     var expected_randomness2 = generator.last_randomness;
//     expected_randomness2[9] = 0x00;
//     expected_randomness2[8] += 1;
//     try std.testing.expect(std.mem.eql(u8, ulid2.randomness[0..], expected_randomness2[0..]));
// }
//
test "Decoding the maximum ULID string succeeds" {
    var buffer: [26]u8 = undefined;
    const max_ulid = Ulid{
        .timestamp = 0xFFFFFFFFFFFF,
        .randomness = [10]u8{ 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF },
    };
    try max_ulid.encode(&buffer);

    var decoded_ulid: Ulid = undefined;
    try Ulid.decode(buffer[0..], &decoded_ulid);

    try std.testing.expect(decoded_ulid.timestamp == max_ulid.timestamp);
    try std.testing.expect(std.mem.eql(u8, decoded_ulid.randomness[0..], max_ulid.randomness[0..]));
}

test "ULID encoding and decoding with known values" {
    // Example ULID: 01AN4Z07BY79KA1307SR9X4MV3
    const known_ulid_str = "01AN4Z07BY79KA1307SR9X4MV3";
    var decoded_ulid: Ulid = undefined;
    try Ulid.decode(known_ulid_str[0..], &decoded_ulid);

    // Encode the decoded ULID back to string
    var buffer: [26]u8 = undefined;
    try decoded_ulid.encode(&buffer);

    // Verify that encoding the decoded ULID matches the original string
    try std.testing.expect(std.mem.eql(u8, buffer[0..], known_ulid_str[0..]));
}

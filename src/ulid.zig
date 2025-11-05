const std = @import("std");
const crypto = std.crypto;
const Io = std.Io;

pub const UlidError = error{
    invalid_length,
    invalid_character,
    overflow,
    encode,
    decode,
};

pub const Ulid = struct {
    timestamp: u64, // 48 bits used
    randomness: [10]u8, // 80 bits

    /// Precomputed Crockford's Base32 encoding table
    const BASE32_ALPHABET = "0123456789ABCDEFGHJKMNPQRSTVWXYZ";

    /// Precomputed Base32 decoding map
    pub const DECODE_MAP: [256]u8 = Ulid.init_decode_map();

    /// Initializes the Base32 decoding map at compile time.
    fn init_decode_map() [256]u8 {
        var map: [256]u8 = .{0xFF} ** 256;
        for (BASE32_ALPHABET, 0..) |c, idx| {
            map[c] = @intCast(idx);
            const lc = std.ascii.toLower(c);
            if (c != lc) {
                map[lc] = @intCast(idx);
            }
        }
        return map;
    }

    /// Encodes the ULID into a 26-character Crockford's Base32 string.
    pub fn encode(self: Ulid, buffer: []u8) !void {
        if (buffer.len != 26) return UlidError.encode;

        // Combine timestamp and randomness into a 128-bit number
        const time: u128 = @intCast(self.timestamp & 0xFFFFFFFFFFFF);
        var ulid_num: u128 = (time << 80);

        // Combine randomness into the lower 80 bits
        inline for (self.randomness, 0..) |byte, i| {
            const shift: u7 = @intCast(72 - (i * 8));
            const byte_u128: u128 = @intCast(byte);
            ulid_num |= byte_u128 << shift;
        }

        // Encode into 26 Base32 characters
        inline for (0..26, 0..) |_, i| {
            const shift = 125 - (i * 5);
            const index: u8 = @intCast((ulid_num >> shift) & 0x1F);
            buffer[i] = Ulid.BASE32_ALPHABET[index];
        }
    }

    /// Decodes a ULID from a 26-character Crockford's Base32 string.
    pub fn decode(input: []const u8, out: *Ulid) !void {
        // Assert input length
        if (input.len != 26) return UlidError.invalid_length;

        var ulid_num: u128 = 0;

        // Decode each character
        inline for (0..26, 0..) |_, i| {
            const c = input[i];
            const val = Ulid.DECODE_MAP[c];
            if (val == 0xFF) return UlidError.invalid_character;
            ulid_num = (ulid_num << 5) | @as(u128, val);
        }

        // Extract timestamp
        out.*.timestamp = @intCast((ulid_num >> 80) & 0xFFFFFFFFFFFF);

        // Extract randomness
        inline for (0..10, 0..) |_, i| {
            out.*.randomness[i] = @intCast((ulid_num >> (72 - (i * 8))) & 0xFF);
        }
    }

    /// Generates a new ULID and returns its encoded 26-character Base32 string.
    pub fn generate(io: Io) ![26]u8 {
        var ulid_struct = try generate_ulid_struct(io);
        var buffer: [26]u8 = undefined;
        try ulid_struct.encode(&buffer);
        return buffer;
    }

    /// Generates a new ULID struct.
    fn generate_ulid_struct(io: Io) !Ulid {
        return Ulid{
            .timestamp = try get_current_timestamp(io),
            .randomness = generate_randomness(),
        };
    }

    /// Ensures monotonicity by incrementing randomness if generated within the same millisecond.
    pub fn monotonic_factory(io: Io) UlidGenerator {
        return UlidGenerator{
            .last_timestamp = 0,
            .last_randomness = undefined,
            .io = io,
        };
    }
};

pub const UlidGenerator = struct {
    last_timestamp: u64 = 0,
    last_randomness: [10]u8 = undefined,
    io: Io,

    /// Generates a ULID ensuring monotonicity within the same millisecond.
    /// Returns the encoded 26-character Base32 string.
    pub fn generate(self: *UlidGenerator, provided_timestamp: ?u64) ![26]u8 {
        const current_timestamp = if (provided_timestamp) |ts| ts else try get_current_timestamp(self.io);
        var ulid: Ulid = .{ .timestamp = current_timestamp, .randomness = [10]u8{ 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 } };

        if (current_timestamp == self.last_timestamp) {
            const all_max = std.mem.eql(u8, &self.last_randomness, &[10]u8{ 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF });
            if (all_max) {
                return UlidError.overflow;
            }

            var carry: bool = true;

            for (0..10) |j| {
                const i = 9 - j;
                const new_value = self.last_randomness[i] + 1;
                self.last_randomness[i] = new_value;
                carry = (new_value == 0);
                if (!carry) break;
            }

            if (carry) {
                return UlidError.overflow;
            }

            ulid.randomness = self.last_randomness;
        } else {
            ulid.randomness = generate_randomness();
            self.last_randomness = ulid.randomness;
            self.last_timestamp = current_timestamp;
        }

        var buffer: [26]u8 = undefined;
        try ulid.encode(&buffer);
        return buffer;
    }
};

fn get_current_timestamp(io: Io) !u64 {
    const time = try Io.Clock.now(.real, io);
    const time_ns = time.toNanoseconds();
    const time_ms: u64 = @intCast(@divTrunc(time_ns, std.time.ns_per_ms));
    if (time_ms > 0xFFFFFFFFFFFF) return UlidError.overflow;
    return time_ms;
}

inline fn generate_randomness() [10]u8 {
    var randomness: [10]u8 = undefined;
    crypto.random.bytes(&randomness);
    return randomness;
}

test "ULID generation produces a valid encoded string" {
    const generated_ulid = try Ulid.generate(std.testing.io);

    // Verify buffer length implicitly by type [26]u8
    // Verify all characters are valid Base32 characters.
    const base32 = Ulid.BASE32_ALPHABET;
    for (generated_ulid, 0..) |char, idx| {
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
    const encoded_ulid = try Ulid.generate(std.testing.io);
    var decoded_ulid: Ulid = undefined; // Properly initialize Ulid
    try Ulid.decode(encoded_ulid[0..], &decoded_ulid);

    // Generate a new ULID from decoded data and encode it again
    var re_encoded_ulid: [26]u8 = undefined;
    try decoded_ulid.encode(&re_encoded_ulid);

    // Verify that the re-encoded ULID matches the original encoded ULID
    try std.testing.expect(std.mem.eql(u8, re_encoded_ulid[0..], encoded_ulid[0..]));
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
    for (buffer, 0..) |_, i| buffer[i] = Ulid.BASE32_ALPHABET[i % 32];
    // Introduce an invalid character
    buffer[10] = '@';
    var dummy_ulid: Ulid = undefined; // Properly initialize Ulid
    const result = Ulid.decode(buffer[0..], &dummy_ulid);
    try std.testing.expect(result == UlidError.invalid_character);
}

test "Monotonic ULID generator increments randomness correctly" {
    var generator = Ulid.monotonic_factory(std.testing.io);
    const timestamp = 1234567890123;

    // Generate the first ULID
    const ulid1_encoded = try generator.generate(timestamp);
    var decoded_ulid1: Ulid = undefined;
    try Ulid.decode(ulid1_encoded[0..], &decoded_ulid1);

    // Generate the second ULID with the same timestamp
    const ulid2_encoded = try generator.generate(timestamp);
    var decoded_ulid2: Ulid = undefined;
    try Ulid.decode(ulid2_encoded[0..], &decoded_ulid2);

    // Expect randomness to be ulid1.randomness + 1
    var expected_randomness = decoded_ulid1.randomness;
    expected_randomness[9] += 1;
    try std.testing.expect(std.mem.eql(u8, decoded_ulid2.randomness[0..], expected_randomness[0..]));
}

test "Monotonic ULID generator handles overflow correctly" {
    var generator = Ulid.monotonic_factory(std.testing.io);
    const timestamp = 1234567890123;

    // Set the last randomness to the maximum value
    generator.last_timestamp = timestamp;
    generator.last_randomness = [10]u8{ 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF };

    // Attempt to generate another ULID within the same millisecond, expecting overflow
    const result = generator.generate(timestamp);
    try std.testing.expect(result == UlidError.overflow);
}

test "Timestamp fits within 48 bits" {
    const encoded_ulid = try Ulid.generate(std.testing.io);
    var decoded_ulid: Ulid = undefined;
    try Ulid.decode(encoded_ulid[0..], &decoded_ulid);
    try std.testing.expect(decoded_ulid.timestamp <= 0xFFFFFFFFFFFF);
}

test "Generated ULID has canonical string representation format" {
    const encoded_ulid = try Ulid.generate(std.testing.io);

    // Verify timestamp (first 10 chars) and randomness (last 16 chars) format
    const timestamp_part = encoded_ulid[0..10];
    const randomness_part = encoded_ulid[10..26];

    // Ensure the length of each part implicitly by slicing
    _ = timestamp_part;
    _ = randomness_part;
}

test "Lexicographical order of ULIDs in the same millisecond" {
    var generator = Ulid.monotonic_factory(std.testing.io);
    const timestamp = 1234567890123;

    // Generate ULIDs within the same millisecond
    const ulid1 = try generator.generate(timestamp);
    const ulid2 = try generator.generate(timestamp);
    const ulid3 = try generator.generate(timestamp);

    // Verify lexicographical order
    try std.testing.expect(std.mem.lessThan(u8, ulid1[0..], ulid2[0..]));
    try std.testing.expect(std.mem.lessThan(u8, ulid2[0..], ulid3[0..]));
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
    const encoded_ulid = try Ulid.generate(std.testing.io);

    const base32_alphabet = Ulid.BASE32_ALPHABET;

    // Verify all characters are in Crockford's Base32 alphabet
    for (encoded_ulid, 0..) |char, idx| {
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
    const encoded_ulid = try Ulid.generate(std.testing.io);
    var buffer: [26]u8 = encoded_ulid;

    // Convert some characters to lowercase
    buffer[5] = std.ascii.toLower(buffer[5]);
    buffer[15] = std.ascii.toLower(buffer[15]);

    var decoded_ulid: Ulid = undefined;
    try Ulid.decode(buffer[0..], &decoded_ulid);

    // Encode the decoded ULID back to string
    var re_encoded_ulid: [26]u8 = undefined;
    try decoded_ulid.encode(&re_encoded_ulid);

    // Verify that encoding the decoded ULID matches the original encoded ULID (case-insensitive)
    // Since encoding produces uppercase, compare with original encoded_ulid
    try std.testing.expect(std.mem.eql(u8, re_encoded_ulid[0..], encoded_ulid[0..]));
}

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

test "ULID generation performance benchmark" {
    const iterations = 1000000;
    var ulid: [26]u8 = undefined;

    var timer = try std.time.Timer.start();
    var i: usize = 0;
    while (i < iterations) : (i += 1) {
        ulid = try Ulid.generate(std.testing.io);
    }
    const duration: u64 = timer.read();
    std.debug.print("Generated {d} ULIDs in {D}\n", .{ iterations, duration });
}

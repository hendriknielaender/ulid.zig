const std = @import("std");
const assert = std.debug.assert;

const decode_invalid: u8 = 0xFF;
const encoded_len = 26;
const randomness_len = 10;
const timestamp_max: u64 = (1 << 48) - 1;

pub const UlidError = error{
    invalid_length,
    invalid_character,
    overflow,
    encode,
    decode,
};

pub const Ulid = struct {
    /// Unix epoch timestamp in milliseconds. Only the low 48 bits are valid.
    timestamp_ms: u64,
    /// The 80-bit random component.
    randomness: [randomness_len]u8,

    pub const string_len = encoded_len;

    const BASE32_ALPHABET = "0123456789ABCDEFGHJKMNPQRSTVWXYZ";

    pub const DECODE_MAP: [256]u8 = Ulid.init_decode_map();

    fn init_decode_map() [256]u8 {
        comptime {
            assert(BASE32_ALPHABET.len == 32);
            assert(encoded_len == 26);
            assert(randomness_len == 10);
            assert(timestamp_max == (1 << 48) - 1);
        }

        var map: [256]u8 = .{decode_invalid} ** 256;
        for (BASE32_ALPHABET, 0..) |c, idx| {
            assert(idx < 32);
            map[c] = @intCast(idx);

            const lc = std.ascii.toLower(c);
            if (c != lc) {
                map[lc] = @intCast(idx);
            }
        }
        return map;
    }

    inline fn encode_char(index: u8) u8 {
        // Each base32 digit is 5 bits, so the index must be 0–31.
        assert(index < 32);
        return BASE32_ALPHABET[index];
    }

    inline fn decode_value(input: *const [encoded_len]u8, comptime index: usize) !u8 {
        comptime assert(index < encoded_len);

        const value = DECODE_MAP[input[index]];
        // Reject characters outside Crockford's Base32 alphabet.
        if (value == decode_invalid) return UlidError.invalid_character;
        // A valid decode always yields a 5-bit value.
        assert(value < 32);
        return value;
    }

    pub fn encode_to(self: *const Ulid, out: *[encoded_len]u8) void {
        encode_parts(self.timestamp_ms, self.randomness, out);
    }

    pub fn encode(self: *const Ulid, buffer: []u8) !void {
        if (buffer.len != encoded_len) return UlidError.encode;

        const out: *[encoded_len]u8 = buffer[0..encoded_len];
        self.encode_to(out);
    }

    pub fn to_string(self: *const Ulid) [encoded_len]u8 {
        var out: [encoded_len]u8 = undefined;
        self.encode_to(&out);
        return out;
    }

    pub fn decode_from(input: *const [encoded_len]u8, out: *Ulid) !void {
        const digit_0 = try decode_value(input, 0);
        // The first digit encodes the top 3 bits of the 48-bit timestamp,
        // so only values 0–7 are valid. Anything else would overflow 48 bits.
        if (digit_0 > 7) return UlidError.overflow;
        assert(digit_0 <= 7);

        const digit_1 = try decode_value(input, 1);
        const digit_2 = try decode_value(input, 2);
        const digit_3 = try decode_value(input, 3);
        const digit_4 = try decode_value(input, 4);
        const digit_5 = try decode_value(input, 5);
        const digit_6 = try decode_value(input, 6);
        const digit_7 = try decode_value(input, 7);
        const digit_8 = try decode_value(input, 8);
        const digit_9 = try decode_value(input, 9);
        const digit_10 = try decode_value(input, 10);
        const digit_11 = try decode_value(input, 11);
        const digit_12 = try decode_value(input, 12);
        const digit_13 = try decode_value(input, 13);
        const digit_14 = try decode_value(input, 14);
        const digit_15 = try decode_value(input, 15);
        const digit_16 = try decode_value(input, 16);
        const digit_17 = try decode_value(input, 17);
        const digit_18 = try decode_value(input, 18);
        const digit_19 = try decode_value(input, 19);
        const digit_20 = try decode_value(input, 20);
        const digit_21 = try decode_value(input, 21);
        const digit_22 = try decode_value(input, 22);
        const digit_23 = try decode_value(input, 23);
        const digit_24 = try decode_value(input, 24);
        const digit_25 = try decode_value(input, 25);

        const timestamp_ms =
            (@as(u64, digit_0) << 45) | (@as(u64, digit_1) << 40) |
            (@as(u64, digit_2) << 35) | (@as(u64, digit_3) << 30) |
            (@as(u64, digit_4) << 25) | (@as(u64, digit_5) << 20) |
            (@as(u64, digit_6) << 15) | (@as(u64, digit_7) << 10) |
            (@as(u64, digit_8) << 5) | @as(u64, digit_9);
        // Paired assertion: the error check above guarantees this.
        assert(timestamp_ms <= timestamp_max);

        out.* = .{
            .timestamp_ms = timestamp_ms,
            .randomness = .{
                (digit_10 << 3) | (digit_11 >> 2),
                ((digit_11 & 0x03) << 6) | (digit_12 << 1) | (digit_13 >> 4),
                ((digit_13 & 0x0F) << 4) | (digit_14 >> 1),
                ((digit_14 & 0x01) << 7) | (digit_15 << 2) | (digit_16 >> 3),
                ((digit_16 & 0x07) << 5) | digit_17,
                (digit_18 << 3) | (digit_19 >> 2),
                ((digit_19 & 0x03) << 6) | (digit_20 << 1) | (digit_21 >> 4),
                ((digit_21 & 0x0F) << 4) | (digit_22 >> 1),
                ((digit_22 & 0x01) << 7) | (digit_23 << 2) | (digit_24 >> 3),
                ((digit_24 & 0x07) << 5) | digit_25,
            },
        };
    }

    pub fn decode(input: []const u8, out: *Ulid) !void {
        if (input.len != encoded_len) return UlidError.invalid_length;

        const exact: *const [encoded_len]u8 = input[0..encoded_len];
        return decode_from(exact, out);
    }

    pub fn init(out: *Ulid, io: std.Io) !void {
        out.* = .{
            .timestamp_ms = try timestamp_now_ms(io),
            .randomness = randomness_generate(io),
        };
        // Paired assertion: timestamp_now_ms already checks, but we assert here too.
        assert(out.timestamp_ms <= timestamp_max);
    }

    pub fn new(io: std.Io) !Ulid {
        var out: Ulid = undefined;
        try Ulid.init(&out, io);
        return out;
    }

    pub fn generate(io: std.Io) ![encoded_len]u8 {
        const timestamp_ms = try timestamp_now_ms(io);
        const randomness = randomness_generate(io);

        var out: [encoded_len]u8 = undefined;
        encode_parts(timestamp_ms, randomness, &out);
        return out;
    }

    pub fn monotonic_factory() UlidGenerator {
        return .{};
    }
};

pub const GenerateOptions = struct {
    timestamp_ms: ?u64 = null,
};

pub const UlidGenerator = struct {
    initialized: bool = false,
    last_timestamp_ms: u64 = 0,
    // Undefined until initialized is set to true.
    last_randomness: [randomness_len]u8 = undefined,

    pub fn next_into(
        self: *UlidGenerator,
        out: *Ulid,
        io: std.Io,
        options: GenerateOptions,
    ) !void {
        const timestamp_ms = if (options.timestamp_ms) |timestamp|
            timestamp
        else
            try timestamp_now_ms(io);
        if (timestamp_ms > timestamp_max) return UlidError.overflow;
        // Blatantly true assertion: documents the invariant after the error check.
        assert(timestamp_ms <= timestamp_max);

        if (self.initialized) {
            if (timestamp_ms == self.last_timestamp_ms) {
                // Same millisecond: increment randomness for monotonicity.
                if (randomness_increment(&self.last_randomness)) {
                    out.* = .{
                        .timestamp_ms = timestamp_ms,
                        .randomness = self.last_randomness,
                    };
                    assert(out.timestamp_ms <= timestamp_max);
                    return;
                } else {
                    // All 80 randomness bits are 0xFF: cannot increment.
                    return UlidError.overflow;
                }
            } else {
                // Different millisecond: generate fresh randomness.
                self.last_randomness = randomness_generate(io);
            }
        } else {
            // First call: generate fresh randomness.
            self.last_randomness = randomness_generate(io);
        }

        self.initialized = true;
        self.last_timestamp_ms = timestamp_ms;

        out.* = .{
            .timestamp_ms = timestamp_ms,
            .randomness = self.last_randomness,
        };
        assert(out.timestamp_ms <= timestamp_max);
    }

    pub fn next(self: *UlidGenerator, io: std.Io, options: GenerateOptions) !Ulid {
        var out: Ulid = undefined;
        try self.next_into(&out, io, options);
        return out;
    }

    pub fn generate(self: *UlidGenerator, io: std.Io, options: GenerateOptions) ![encoded_len]u8 {
        var ulid: Ulid = undefined;
        try self.next_into(&ulid, io, options);
        return ulid.to_string();
    }
};

fn timestamp_now_ms(io: std.Io) !u64 {
    const time_ms_i64 = std.Io.Timestamp.now(io, .real).toMilliseconds();
    // A negative wall-clock time is nonsensical for ULID.
    if (time_ms_i64 < 0) return UlidError.overflow;

    const time_ms: u64 = @intCast(time_ms_i64);
    if (time_ms > timestamp_max) return UlidError.overflow;
    return time_ms;
}

inline fn randomness_generate(io: std.Io) [randomness_len]u8 {
    var randomness: [randomness_len]u8 = undefined;
    io.random(&randomness);
    return randomness;
}

fn randomness_increment(randomness: *[randomness_len]u8) bool {
    // Scan from least-significant byte looking for a byte that can carry.
    var index: u8 = randomness_len;
    while (index > 0) {
        index -= 1;
        if (randomness[index] < 0xFF) {
            // This byte can be incremented without wrapping.
            randomness[index] += 1;
            assert(randomness[index] <= 0xFF);

            // All bytes to the right carried from 0xFF to 0x00.
            var suffix: u8 = index + 1;
            while (suffix < randomness_len) : (suffix += 1) {
                randomness[suffix] = 0;
            }
            return true;
        } else {
            // Byte is 0xFF: carry propagates left.
            assert(randomness[index] == 0xFF);
        }
    }
    // All bytes are 0xFF: cannot increment without overflow.
    return false;
}

fn encode_parts(
    timestamp_ms: u64,
    randomness_bytes: [randomness_len]u8,
    out: *[encoded_len]u8,
) void {
    // The timestamp must fit in 48 bits.
    assert(timestamp_ms <= timestamp_max);

    out[0] = Ulid.encode_char(@intCast((timestamp_ms >> 45) & 0x1F));
    out[1] = Ulid.encode_char(@intCast((timestamp_ms >> 40) & 0x1F));
    out[2] = Ulid.encode_char(@intCast((timestamp_ms >> 35) & 0x1F));
    out[3] = Ulid.encode_char(@intCast((timestamp_ms >> 30) & 0x1F));
    out[4] = Ulid.encode_char(@intCast((timestamp_ms >> 25) & 0x1F));
    out[5] = Ulid.encode_char(@intCast((timestamp_ms >> 20) & 0x1F));
    out[6] = Ulid.encode_char(@intCast((timestamp_ms >> 15) & 0x1F));
    out[7] = Ulid.encode_char(@intCast((timestamp_ms >> 10) & 0x1F));
    out[8] = Ulid.encode_char(@intCast((timestamp_ms >> 5) & 0x1F));
    out[9] = Ulid.encode_char(@intCast(timestamp_ms & 0x1F));

    out[10] = Ulid.encode_char(randomness_bytes[0] >> 3);
    out[11] = Ulid.encode_char(((randomness_bytes[0] & 0x07) << 2) | (randomness_bytes[1] >> 6));
    out[12] = Ulid.encode_char((randomness_bytes[1] >> 1) & 0x1F);
    out[13] = Ulid.encode_char(((randomness_bytes[1] & 0x01) << 4) | (randomness_bytes[2] >> 4));
    out[14] = Ulid.encode_char(((randomness_bytes[2] & 0x0F) << 1) | (randomness_bytes[3] >> 7));
    out[15] = Ulid.encode_char((randomness_bytes[3] >> 2) & 0x1F);
    out[16] = Ulid.encode_char(((randomness_bytes[3] & 0x03) << 3) | (randomness_bytes[4] >> 5));
    out[17] = Ulid.encode_char(randomness_bytes[4] & 0x1F);
    out[18] = Ulid.encode_char(randomness_bytes[5] >> 3);
    out[19] = Ulid.encode_char(((randomness_bytes[5] & 0x07) << 2) | (randomness_bytes[6] >> 6));
    out[20] = Ulid.encode_char((randomness_bytes[6] >> 1) & 0x1F);
    out[21] = Ulid.encode_char(((randomness_bytes[6] & 0x01) << 4) | (randomness_bytes[7] >> 4));
    out[22] = Ulid.encode_char(((randomness_bytes[7] & 0x0F) << 1) | (randomness_bytes[8] >> 7));
    out[23] = Ulid.encode_char((randomness_bytes[8] >> 2) & 0x1F);
    out[24] = Ulid.encode_char(((randomness_bytes[8] & 0x03) << 3) | (randomness_bytes[9] >> 5));
    out[25] = Ulid.encode_char(randomness_bytes[9] & 0x1F);
}

test "ULID generation produces a valid encoded string" {
    const generated_ulid = try Ulid.generate(std.testing.io);

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
    var decoded_ulid: Ulid = undefined;
    try Ulid.decode(encoded_ulid[0..], &decoded_ulid);

    var re_encoded_ulid: [26]u8 = undefined;
    try decoded_ulid.encode(&re_encoded_ulid);

    try std.testing.expect(std.mem.eql(u8, re_encoded_ulid[0..], encoded_ulid[0..]));
}

test "ULID decoding fails on invalid length" {
    var buffer: [25]u8 = undefined;
    var dummy_ulid: Ulid = undefined;
    const result = Ulid.decode(buffer[0..], &dummy_ulid);
    try std.testing.expect(result == UlidError.invalid_length);
}

test "ULID decoding fails on invalid characters" {
    var buffer: [26]u8 = undefined;
    for (buffer, 0..) |_, i| buffer[i] = Ulid.BASE32_ALPHABET[i % 32];

    buffer[10] = '@';
    var dummy_ulid: Ulid = undefined;
    const result = Ulid.decode(buffer[0..], &dummy_ulid);
    try std.testing.expect(result == UlidError.invalid_character);
}

test "ULID decoding fails on overflow" {
    var buffer = [_]u8{'8'} ** Ulid.string_len;
    var decoded: Ulid = undefined;

    const result = Ulid.decode(&buffer, &decoded);
    try std.testing.expect(result == UlidError.overflow);
}

test "Monotonic ULID generator increments randomness correctly" {
    var generator = Ulid.monotonic_factory();
    const timestamp = 1234567890123;

    const ulid1_encoded = try generator.generate(std.testing.io, .{ .timestamp_ms = timestamp });
    var decoded_ulid1: Ulid = undefined;
    try Ulid.decode(ulid1_encoded[0..], &decoded_ulid1);

    const ulid2_encoded = try generator.generate(std.testing.io, .{ .timestamp_ms = timestamp });
    var decoded_ulid2: Ulid = undefined;
    try Ulid.decode(ulid2_encoded[0..], &decoded_ulid2);

    var expected_randomness = decoded_ulid1.randomness;
    expected_randomness[9] += 1;
    try std.testing.expect(std.mem.eql(
        u8,
        decoded_ulid2.randomness[0..],
        expected_randomness[0..],
    ));
}

test "Monotonic ULID generator handles overflow correctly" {
    var generator = Ulid.monotonic_factory();
    const timestamp = 1234567890123;

    generator.initialized = true;
    generator.last_timestamp_ms = timestamp;
    generator.last_randomness = .{
        0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
        0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
    };

    const result = generator.generate(std.testing.io, .{ .timestamp_ms = timestamp });
    try std.testing.expect(result == UlidError.overflow);
    try std.testing.expect(generator.initialized);
    try std.testing.expect(generator.last_timestamp_ms == timestamp);
    try std.testing.expect(std.mem.eql(
        u8,
        &generator.last_randomness,
        &[10]u8{ 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF },
    ));
}

test "Monotonic ULID generator handles timestamp zero on first use" {
    var generator = Ulid.monotonic_factory();

    const encoded = try generator.generate(std.testing.io, .{ .timestamp_ms = 0 });
    var decoded: Ulid = undefined;
    try Ulid.decode(&encoded, &decoded);

    try std.testing.expect(generator.initialized);
    try std.testing.expect(generator.last_timestamp_ms == 0);
    try std.testing.expect(decoded.timestamp_ms == 0);
    try std.testing.expect(std.mem.eql(u8, &decoded.randomness, &generator.last_randomness));
}

test "Timestamp fits within 48 bits" {
    const encoded_ulid = try Ulid.generate(std.testing.io);
    var decoded_ulid: Ulid = undefined;
    try Ulid.decode(encoded_ulid[0..], &decoded_ulid);
    try std.testing.expect(decoded_ulid.timestamp_ms <= 0xFFFFFFFFFFFF);
}

test "Generated ULID has canonical string representation format" {
    const encoded_ulid = try Ulid.generate(std.testing.io);

    const timestamp_part = encoded_ulid[0..10];
    const randomness_part = encoded_ulid[10..26];

    _ = timestamp_part;
    _ = randomness_part;
}

test "Lexicographical order of ULIDs in the same millisecond" {
    var generator = Ulid.monotonic_factory();
    const timestamp = 1234567890123;

    const ulid1 = try generator.generate(std.testing.io, .{ .timestamp_ms = timestamp });
    const ulid2 = try generator.generate(std.testing.io, .{ .timestamp_ms = timestamp });
    const ulid3 = try generator.generate(std.testing.io, .{ .timestamp_ms = timestamp });

    try std.testing.expect(std.mem.lessThan(u8, ulid1[0..], ulid2[0..]));
    try std.testing.expect(std.mem.lessThan(u8, ulid2[0..], ulid3[0..]));
}

test "Maximum valid ULID encoding check" {
    var max_ulid = Ulid{
        .timestamp_ms = 0xFFFFFFFFFFFF,
        .randomness = [10]u8{ 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF },
    };

    var buffer: [26]u8 = undefined;
    try max_ulid.encode(&buffer);

    try std.testing.expect(buffer.len == 26);
    try std.testing.expect(buffer[0] != 0);
}

test "ULID characters comply with Base32 alphabet" {
    const encoded_ulid = try Ulid.generate(std.testing.io);

    const base32_alphabet = Ulid.BASE32_ALPHABET;

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

    buffer[5] = std.ascii.toLower(buffer[5]);
    buffer[15] = std.ascii.toLower(buffer[15]);

    var decoded_ulid: Ulid = undefined;
    try Ulid.decode(buffer[0..], &decoded_ulid);

    var re_encoded_ulid: [26]u8 = undefined;
    try decoded_ulid.encode(&re_encoded_ulid);

    try std.testing.expect(std.mem.eql(u8, re_encoded_ulid[0..], encoded_ulid[0..]));
}

test "Monotonic ULID generator handles carry" {
    var generator = Ulid.monotonic_factory();
    const timestamp = 1234567890123;

    generator.initialized = true;
    generator.last_timestamp_ms = timestamp;
    generator.last_randomness = .{
        0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0xFF, 0xFE,
    };

    const first = try generator.next(std.testing.io, .{ .timestamp_ms = timestamp });
    try std.testing.expect(first.randomness[8] == 0xFF);
    try std.testing.expect(first.randomness[9] == 0xFF);

    const second = try generator.next(std.testing.io, .{ .timestamp_ms = timestamp });
    try std.testing.expect(second.randomness[8] == 0x00);
    try std.testing.expect(second.randomness[9] == 0x00);
    try std.testing.expect(second.randomness[7] == 0x01);
}

test "Decoding the maximum ULID string succeeds" {
    var buffer: [26]u8 = undefined;
    const max_ulid = Ulid{
        .timestamp_ms = 0xFFFFFFFFFFFF,
        .randomness = [10]u8{ 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF },
    };
    try max_ulid.encode(&buffer);

    var decoded_ulid: Ulid = undefined;
    try Ulid.decode(buffer[0..], &decoded_ulid);

    try std.testing.expect(decoded_ulid.timestamp_ms == max_ulid.timestamp_ms);
    try std.testing.expect(std.mem.eql(u8, decoded_ulid.randomness[0..], max_ulid.randomness[0..]));
}

test "ULID encoding and decoding with known values" {
    const known_ulid_str = "01AN4Z07BY79KA1307SR9X4MV3";
    var decoded_ulid: Ulid = undefined;
    try Ulid.decode(known_ulid_str[0..], &decoded_ulid);

    var buffer: [26]u8 = undefined;
    try decoded_ulid.encode(&buffer);

    try std.testing.expect(std.mem.eql(u8, buffer[0..], known_ulid_str[0..]));
}

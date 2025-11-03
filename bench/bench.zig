const std = @import("std");
const zbench = @import("zbench");
const Ulid = @import("ulid").Ulid;

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
var io_instance: std.Io.Threaded = .init_single_threaded;
const io = io_instance.io();

/// Utility function to create a known ULID string for parsing benchmarks.
fn get_known_ulid() [26]u8 {
    return [_]u8{
        '0', '1', 'A', 'N', '4', 'Z', '0', '7', 'B', 'Y',
        '7', '9', 'K', 'A', '1', '3', '0', '7', 'S', 'R',
        '9', 'X', '4', 'M', 'V', '3',
    };
}

/// Benchmark for ULID generation.
fn benchmark_generate(_: std.mem.Allocator) void {
    for (0..1000) |_| {
        const ulid_encoded = Ulid.generate(io) catch unreachable;
        std.mem.doNotOptimizeAway(ulid_encoded); // Prevent compiler optimizations
    }
}

/// Benchmark for ULID generation using the monotonic generator.
fn benchmark_generate_monotonic(_: std.mem.Allocator) void {
    var generator = Ulid.monotonic_factory();
    for (0..1000) |_| {
        const ulid_encoded = generator.generate(null) catch unreachable;
        std.mem.doNotOptimizeAway(ulid_encoded); // Prevent compiler optimizations
    }
}

/// Benchmark for ULID decoding.
fn benchmark_decode(_: std.mem.Allocator) void {
    const known_ulid = get_known_ulid();
    for (0..1000) |_| {
        var decoded_ulid: Ulid = undefined;
        Ulid.decode(known_ulid[0..], &decoded_ulid) catch unreachable;
        std.mem.doNotOptimizeAway(decoded_ulid); // Prevent compiler optimizations
    }
}

/// Benchmark for generating and encoding ULIDs.
fn benchmark_generate_and_encode(_: std.mem.Allocator) void {
    for (0..1000) |_| {
        const ulid_encoded = Ulid.generate(io) catch unreachable;
        std.mem.doNotOptimizeAway(ulid_encoded); // Prevent compiler optimizations
    }
}

/// Benchmark for ULID parsing.
fn benchmark_parse(_: std.mem.Allocator) void {
    const known_ulid_str = get_known_ulid();
    for (0..1000) |_| {
        var decoded_ulid: Ulid = undefined;
        Ulid.decode(known_ulid_str[0..], &decoded_ulid) catch unreachable;
        std.mem.doNotOptimizeAway(decoded_ulid); // Prevent compiler optimizations
    }
}

/// Benchmark for ULID string comparison.
fn benchmark_compare(_: std.mem.Allocator) void {
    const ulid1 = Ulid.generate(io) catch unreachable;
    const ulid2 = Ulid.generate(io) catch unreachable;
    for (0..1000) |_| {
        const cmp = std.mem.lessThan(u8, ulid1[0..], ulid2[0..]);
        std.mem.doNotOptimizeAway(cmp); // Prevent compiler optimizations
    }
}

/// Benchmark for ULID parsing with lowercase characters.
fn benchmark_decode_lowercase(_: std.mem.Allocator) void {
    const known_ulid = get_known_ulid();
    var buffer: [26]u8 = known_ulid;
    // Convert some characters to lowercase
    buffer[5] = std.ascii.toLower(buffer[5]);
    buffer[15] = std.ascii.toLower(buffer[15]);
    for (0..1000) |_| {
        var decoded_ulid: Ulid = undefined;
        Ulid.decode(buffer[0..], &decoded_ulid) catch unreachable;
        std.mem.doNotOptimizeAway(decoded_ulid); // Prevent compiler optimizations
    }
}

/// Benchmark for decoding the maximum ULID string.
fn benchmark_decode_max_ulid(_: std.mem.Allocator) void {
    var buffer: [26]u8 = undefined;
    const max_ulid = Ulid{ .timestamp = 0xFFFFFFFFFFFF, .randomness = [10]u8{ 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF } };
    max_ulid.encode(&buffer) catch unreachable;
    for (0..1000) |_| {
        var decoded_ulid: Ulid = undefined;
        Ulid.decode(buffer[0..], &decoded_ulid) catch unreachable;
        std.mem.doNotOptimizeAway(decoded_ulid); // Prevent compiler optimizations
    }
}

/// Benchmark for comparing ULIDs lexicographically.
fn benchmark_compare_lexicographical(_: std.mem.Allocator) void {
    var generator = Ulid.monotonic_factory();
    const timestamp = 1234567890123;

    // Generate multiple ULIDs with the same timestamp to ensure lex order
    var ulids: [1000][26]u8 = undefined;
    for (&ulids) |*ulid| {
        const encoded = generator.generate(timestamp) catch unreachable;
        std.mem.copyForwards(u8, ulid, &encoded);
    }

    for (1..ulids.len) |i| {
        const cmp = std.mem.lessThan(u8, ulids[i - 1][0..], ulids[i][0..]);
        std.mem.doNotOptimizeAway(cmp); // Prevent compiler optimizations
    }
}

/// Main function to register and run all benchmarks.
pub fn main() !void {
    var stdout_buffer: [4096]u8 = undefined;
    var stdout_writer = std.fs.File.stdout().writer(&stdout_buffer);
    const stdout = &stdout_writer.interface;

    var bench = zbench.Benchmark.init(gpa.allocator(), .{});
    defer {
        const deinit_status = gpa.deinit();
        if (deinit_status == .leak) std.debug.panic("Memory leak detected", .{});
    }

    defer bench.deinit();

    // Register benchmarks with descriptive names
    try bench.add("ULID_Generate", benchmark_generate, .{
        .iterations = 10_000,
        .track_allocations = false,
    });
    // try bench.add("ULID_Generate_Monotonic", benchmark_generate_monotonic, .{
    //     .iterations = 10_000,
    //     .track_allocations = false,
    // });
    // try bench.add("ULID_Decode", benchmark_decode, .{
    //     .iterations = 10_000,
    //     .track_allocations = false,
    // });
    // try bench.add("ULID_Generate_and_Encode", benchmark_generate_and_encode, .{
    //     .iterations = 10_000,
    //     .track_allocations = false,
    // });
    // try bench.add("ULID_Parse", benchmark_parse, .{
    //     .iterations = 10_000,
    //     .track_allocations = false,
    // });
    // try bench.add("ULID_Compare", benchmark_compare, .{
    //     .iterations = 10_000,
    //     .track_allocations = false,
    // });
    // try bench.add("ULID_Decode_Lowercase", benchmark_decode_lowercase, .{
    //     .iterations = 10_000,
    //     .track_allocations = false,
    // });
    // try bench.add("ULID_Decode_MaxULID", benchmark_decode_max_ulid, .{
    //     .iterations = 10_000,
    //     .track_allocations = false,
    // });
    // try bench.add("ULID_Compare_Lexicographical", benchmark_compare_lexicographical, .{
    //     .iterations = 10_000,
    //     .track_allocations = false,
    // });

    try stdout.writeAll("\n");
    try bench.run(stdout);
    try stdout.flush();
}

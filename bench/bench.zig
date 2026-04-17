const std = @import("std");
const zbench = @import("zbench");
const Ulid = @import("ulid").Ulid;

const batch_count_max: u32 = 1000;
const benchmark_iterations: u32 = 10_000;

var benchmark_io: std.Io = undefined;

fn get_known_ulid() [26]u8 {
    return [_]u8{
        '0', '1', 'A', 'N', '4', 'Z', '0', '7', 'B', 'Y',
        '7', '9', 'K', 'A', '1', '3', '0', '7', 'S', 'R',
        '9', 'X', '4', 'M', 'V', '3',
    };
}

fn get_known_ulid_struct() Ulid {
    return .{
        .timestamp_ms = 1_234_567_890_123,
        .randomness = .{ 0, 1, 2, 3, 4, 5, 6, 7, 8, 9 },
    };
}

fn benchmark_new(_: std.mem.Allocator) void {
    for (0..batch_count_max) |_| {
        const ulid = Ulid.new(benchmark_io) catch unreachable;
        std.mem.doNotOptimizeAway(&ulid);
    }
}

fn benchmark_init(_: std.mem.Allocator) void {
    for (0..batch_count_max) |_| {
        var ulid: Ulid = undefined;
        Ulid.init(&ulid, benchmark_io) catch unreachable;
        std.mem.doNotOptimizeAway(&ulid);
    }
}

fn benchmark_generate(_: std.mem.Allocator) void {
    for (0..batch_count_max) |_| {
        const ulid_encoded = Ulid.generate(benchmark_io) catch unreachable;
        std.mem.doNotOptimizeAway(&ulid_encoded);
    }
}

fn benchmark_from_string(_: std.mem.Allocator) void {
    const known_ulid = get_known_ulid();
    for (0..batch_count_max) |_| {
        var decoded_ulid: Ulid = undefined;
        Ulid.decode_from(&known_ulid, &decoded_ulid) catch unreachable;
        std.mem.doNotOptimizeAway(&decoded_ulid);
    }
}

fn benchmark_to_str(_: std.mem.Allocator) void {
    const ulid = get_known_ulid_struct();
    for (0..batch_count_max) |_| {
        var encoded: [Ulid.string_len]u8 = undefined;
        ulid.encode_to(&encoded);
        std.mem.doNotOptimizeAway(&encoded);
    }
}

fn benchmark_to_string(_: std.mem.Allocator) void {
    const ulid = get_known_ulid_struct();
    for (0..batch_count_max) |_| {
        const encoded_ulid = ulid.to_string();
        std.mem.doNotOptimizeAway(&encoded_ulid);
    }
}

fn benchmark_generator_generate(_: std.mem.Allocator) void {
    var generator = Ulid.monotonic_factory();
    for (0..batch_count_max) |_| {
        const encoded = generator.generate(benchmark_io, .{}) catch unreachable;
        std.mem.doNotOptimizeAway(&encoded);
    }
}

fn benchmark_generator_fixed(_: std.mem.Allocator) void {
    var generator = Ulid.monotonic_factory();
    for (0..batch_count_max) |_| {
        const encoded = generator.generate(benchmark_io, .{
            .timestamp_ms = 1_234_567_890_123,
        }) catch unreachable;
        std.mem.doNotOptimizeAway(&encoded);
    }
}

fn benchmark_decode_lowercase(_: std.mem.Allocator) void {
    const known_ulid = get_known_ulid();
    var buffer: [26]u8 = known_ulid;
    buffer[5] = std.ascii.toLower(buffer[5]);
    buffer[15] = std.ascii.toLower(buffer[15]);
    for (0..batch_count_max) |_| {
        var decoded_ulid: Ulid = undefined;
        Ulid.decode(buffer[0..], &decoded_ulid) catch unreachable;
        std.mem.doNotOptimizeAway(&decoded_ulid);
    }
}

fn benchmark_decode_max_ulid(_: std.mem.Allocator) void {
    var buffer: [26]u8 = undefined;
    const max_ulid = Ulid{
        .timestamp_ms = 0xFFFFFFFFFFFF,
        .randomness = .{ 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF },
    };
    max_ulid.encode(&buffer) catch unreachable;
    for (0..batch_count_max) |_| {
        var decoded_ulid: Ulid = undefined;
        Ulid.decode(buffer[0..], &decoded_ulid) catch unreachable;
        std.mem.doNotOptimizeAway(&decoded_ulid);
    }
}

pub fn main(init: std.process.Init) !void {
    benchmark_io = init.io;

    var bench = zbench.Benchmark.init(init.gpa, .{});
    defer bench.deinit();

    try bench.add("ULID_New", benchmark_new, .{
        .iterations = benchmark_iterations,
        .track_allocations = false,
    });
    try bench.add("ULID_Init", benchmark_init, .{
        .iterations = benchmark_iterations,
        .track_allocations = false,
    });
    try bench.add("ULID_Generate", benchmark_generate, .{
        .iterations = benchmark_iterations,
        .track_allocations = false,
    });
    try bench.add("ULID_FromString", benchmark_from_string, .{
        .iterations = benchmark_iterations,
        .track_allocations = false,
    });
    try bench.add("ULID_ToStr", benchmark_to_str, .{
        .iterations = benchmark_iterations,
        .track_allocations = false,
    });
    try bench.add("ULID_ToString", benchmark_to_string, .{
        .iterations = benchmark_iterations,
        .track_allocations = false,
    });
    try bench.add("ULID_GeneratorGenerate", benchmark_generator_generate, .{
        .iterations = benchmark_iterations,
        .track_allocations = false,
    });
    try bench.add("ULID_GeneratorFixed", benchmark_generator_fixed, .{
        .iterations = benchmark_iterations,
        .track_allocations = false,
    });
    try bench.add("ULID_DecodeLowercase", benchmark_decode_lowercase, .{
        .iterations = benchmark_iterations,
        .track_allocations = false,
    });
    try bench.add("ULID_DecodeMax", benchmark_decode_max_ulid, .{
        .iterations = benchmark_iterations,
        .track_allocations = false,
    });

    try std.Io.File.stdout().writeStreamingAll(init.io, "\n");
    try bench.run(init.io, .stdout());
}

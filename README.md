# ulid.zig
[![Zig](https://img.shields.io/badge/-Zig-F7A41D?style=flat&logo=zig&logoColor=white)](https://ziglang.org/)
![GitHub Actions Workflow Status](https://img.shields.io/github/actions/workflow/status/hendriknielaender/ulid.zig/unit-test.yml)
[![GitHub Release](https://img.shields.io/github/v/release/hendriknielaender/ulid.zig)](https://github.com/hendriknielaender/ulid.zig/releases)
![GitHub code size in bytes](https://img.shields.io/github/languages/code-size/hendriknielaender/ulid.zig)


A **Universally Unique Lexicographically Sortable Identifier (ULID)** implementation for Zig, providing a robust and efficient way to generate unique identifiers that are both time-based and random.

## Why ULID?

UUID can be suboptimal for many uses-cases because:

- It isn't the most character efficient way of encoding 128 bits of randomness
- UUID v1/v2 is impractical in many environments, as it requires access to a unique, stable MAC address
- UUID v3/v5 requires a unique seed and produces randomly distributed IDs, which can cause fragmentation in many data structures
- UUID v4 provides no other information than randomness which can cause fragmentation in many data structures

## Features

- 128-bit compatibility with UUID
- 1.21e+24 unique ULIDs per millisecond
- Lexicographically sortable!
- Canonically encoded as a 26 character string, as opposed to the 36 character UUID
- Uses Crockford's base32 for better efficiency and readability (5 bits per character)
- Case insensitive
- No special characters (URL safe)
- Monotonic sort order (correctly detects and handles the same millisecond)

## Test Coverage
- ULID Generation: Validates timestamp and randomness.
- Encoding: Ensures ULIDs are correctly encoded into Base32 strings.
- Decoding: Confirms accurate decoding from Base32 strings.
- Monotonicity: Tests that ULIDs generated within the same millisecond are monotonically increasing.
- Overflow Handling: Checks proper error handling when randomness overflows.
- Edge Cases: Validates behavior with maximum ULID values and invalid inputs.

## Specification
For detailed information on the ULID specification, refer to the [ULID Specification](https://github.com/ulid/spec).

## Usage
This library provides an implementation of ULID (Universally Unique Lexicographically Sortable Identifier) generation and decoding in Zig.

### Generating a ULID
You can generate a new ULID as a 26-character Crockford's Base32 string:

```zig
const ulid = try Ulid.generate();
std.debug.print("Generated ULID: {s}\n", .{ulid});
```
This will output a unique, lexicographically sortable string.

### Decoding a ULID
To decode a ULID string into its components (timestamp and randomness):
```zig
const ulid_str = "01AN4Z07BY79KA1307SR9X4MV3";
var decoded_ulid: Ulid = undefined;
try Ulid.decode(ulid_str[0..], &decoded_ulid);
std.debug.print("Decoded ULID: timestamp={d}, randomness={d}\n", .{decoded_ulid.timestamp, decoded_ulid.randomness});
```

### Monotonic ULID Generation
To generate ULIDs with guaranteed monotonicity within the same millisecond, use the `UlidGenerator`:
```zig
var generator = Ulid.monotonic_factory();
const ulid = try generator.generate(null); // Passing `null` uses the current timestamp.
std.debug.print("Generated monotonic ULID: {s}\n", .{ulid});
```
This will ensure that if multiple ULIDs are generated in the same millisecond, their randomness will be incremented to preserve order.

### Handling Errors
This library defines several error types for ULID encoding/decoding, such as:

- `invalid_length` – when the provided ULID string is not 26 characters long.
- `invalid_character` – when the ULID string contains invalid Base32 characters.
- `overflow` – when the timestamp exceeds the maximum allowable value (48 bits).

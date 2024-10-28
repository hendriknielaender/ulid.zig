# ulid.zig

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


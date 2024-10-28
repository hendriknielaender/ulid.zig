# ulid.zig

A **Universally Unique Lexicographically Sortable Identifier (ULID)** implementation for Zig, providing a robust and efficient way to generate unique identifiers that are both time-based and random.

## Why ULID?

ULIDs offer several advantages over traditional UUIDs:

- **Compact Encoding:** ULIDs encode 128 bits of data into a **26-character** string, compared to UUID's 36 characters.
- **Lexicographical Order:** ULIDs are **lexicographically sortable**, making them ideal for database indexing and ordered storage.
- **High Uniqueness:** With **1.21e+24** unique ULIDs per millisecond, the chance of collision is negligible.
- **Readable:** Uses **Crockford's Base32** encoding, excluding ambiguous characters (I, L, O, U) for better readability.
- **Monotonicity:** Ensures that ULIDs generated within the same millisecond are **monotonically increasing**, preserving sort order.

## Features

- **128-bit Compatibility:** Compatible with UUIDs, allowing seamless integration where UUIDs are expected.
- **Crockford's Base32 Encoding:** Efficient and readable encoding without ambiguous characters.
- **Monotonic Generation:** Guarantees that ULIDs generated within the same millisecond are ordered correctly.
- **Cryptographically Secure Randomness:** Utilizes secure PRNGs to ensure randomness.
- **Error Handling:** Comprehensive error handling for invalid inputs and overflow conditions.
- **Comprehensive Testing:** Robust unit tests covering all aspects of ULID generation, encoding, and decoding.


---
sidebar_position: 1
---

# VoidSentryUltimate

VoidSentryUltimate is a schema-driven binary serializer for Roblox Luau, optimized for low overhead. `LuauVS.luau` provides the portable Luau subset for non-roblox environments.

The library is intentionally validation-free. It does not check values, lengths, integer ranges, buffer capacity, or schema compatibility before reading or writing. The sender and receiver must use the same schema at both ends.

## Basic workflow

1. Build a schema from nodes in `VoidSentryUltimate.Types`.
2. Serialize a matching value into a buffer.
3. Send or store that buffer.
4. Deserialize it with the same schema.

```luau
local VoidSentryUltimate = require(path.to.VoidSentryUltimate)
local Types = VoidSentryUltimate.Types

local PlayerState = Types.Struct({
	Health = Types.U16,
	Name = Types.String8,
	Position = Types.Vector,
})

local encoded = VoidSentryUltimate.Serialize(PlayerState, {
	Health = 100,
	Name = "Builder",
	Position = Vector3.new(4, 8, 15),
})

local decoded = VoidSentryUltimate.Deserialize(PlayerState, encoded)
print(decoded.Name, decoded.Health)
```

Schemas are executable serialization nodes, not metadata embedded in the output. Buffers contain only the bytes selected by the schema, so there is no type tag or self-description to recover a missing schema.

## Choose a module

- Use `VoidSentryUltimate.luau` in Roblox. Its Wally package is
  `elentium/voidsentryultimate@1.0.0`. It includes Roblox datatypes, instance
  references, and serializable instances.
- Use `LuauVS.luau` for pure Luau. Its Wally package is
  `elentium/voidsentryultimateluau@1.0.0`. It includes scalar, string, buffer,
  collection, optional, packed-boolean, and `vector` nodes, but no Roblox-only
  types.

## Important constraints

- Invalid values can truncate, wrap, fail inside buffer operations, or produce unreadable data.
- Variable-length values include a length prefix; fixed variants do not.
- The initial serialization scratch buffer is 1,000,000 bytes. Use `SetWriteBufferSize` from the [API](/api/VoidSentryUltimate) when you need a different limit.

Continue with [Installation](./installation.md), then [Schemas](./schemas.md) and the [Type catalog](./types.md). Measured throughput and a Sera comparison are in [Benchmarks](./benchmarks.md).

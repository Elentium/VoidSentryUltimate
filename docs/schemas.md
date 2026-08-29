---
sidebar_position: 3
---

# Schemas

A schema is a serialization node. Primitive nodes are ready to use, while constructors such as `Struct`, `DeltaStruct`, `Array`, `Map`, and `Optional` return composed nodes.

```luau
local Types = VoidSentryUltimate.Types

local Item = Types.Struct({
	Count = Types.U16,
	Id = Types.U32,
	Note = Types.Optional(Types.String8),
})

local Inventory = Types.Array8(Item)
```

The schema is required for both serialization and deserialization:

```luau
local bytes = VoidSentryUltimate.Serialize(Inventory, items)
local copy = VoidSentryUltimate.Deserialize(Inventory, bytes)
```

No schema identifier is written to `bytes`. Changing a schema changes its wire format; old data must continue to use its old schema or be migrated explicitly.

## Struct

`Types.Struct(fields)` serializes every named field with its node. At schema creation, the implementation collects field names and sorts them. Serialization and deserialization use that sorted key order, not table iteration order or the visual order in the schema literal.

```luau
local Transform = Types.Struct({
	Rotation = Types.Vector,
	Position = Types.Vector,
})
```

For this schema, `Position` is written before `Rotation` because the keys are sorted lexicographically. Both ends still need the same field names and field nodes. Do not treat Lua table construction order as a wire-format contract, and do not infer broader deterministic cross-process behavior beyond the implementation's sorted string keys.

## Delta structs

`DeltaStruct` and `DeltaStruct16` serialize only keys present in the input table. Serialization walks the input (not the full schema), looks up each key’s field id, and writes that field. Deserialization returns a sparse table containing only the fields that were present on the wire.

At schema creation, field names are collected and sorted lexicographically to assign stable 1-based field ids. Entry order on the wire follows Luau table iteration order of the input, not sorted key order.

- `DeltaStruct(fields)`: 1-byte present-count and 1-byte field ids (max 255 present fields).
- `DeltaStruct16(fields)`: 2-byte present-count and 2-byte field ids (max 65,535 present fields).

```luau
local PlayerDelta = Types.DeltaStruct({
	Health = Types.U8,
	Name = Types.String8,
	Score = Types.U32,
})

-- Only Health and Score are encoded
local bytes = VoidSentryUltimate.Serialize(PlayerDelta, {
	Health = 100,
	Score = 42,
})
```

Omit keys you do not want to send. Nesting `Optional` inside a delta struct is usually redundant: presence is decided by whether the key exists in the input.

Unknown keys are not validated on the hot path; they will fail when the serializer looks up the field id.

## Arrays

- `Array(node)` writes a 2-byte unsigned element count, then the elements.
- `Array8(node)` writes a 1-byte count.
- `Array24(node)` writes a 3-byte count.
- `ArrayFixed(node, length)` writes no count prefix.

```luau
local RecentScores = Types.ArrayFixed(Types.U16, 3)
local bytes = VoidSentryUltimate.Serialize(RecentScores, { 10, 20, 30 })
```

For a fixed array, the caller must supply exactly the declared number of elements. The serializer iterates the provided array without validating its length, while the deserializer always reads the declared length. A mismatch shifts or truncates the surrounding wire layout.

## Maps

- `Map(keyNode, valueNode)` writes a 2-byte entry count.
- `Map8(keyNode, valueNode)` writes a 1-byte count.
- `Map24(keyNode, valueNode)` writes a 3-byte count.
- `MapFixed(keyNode, valueNode, length)` writes no count prefix.

```luau
local ScoresByUser = Types.Map(Types.U32, Types.U16)
```

Map entries are emitted in Luau table iteration order. The decoder reconstructs the same key/value pairs, but the encoded byte sequence is not promised to be stable across separately constructed maps or processes. If stable bytes matter for hashing or signing, serialize a canonically sorted array of entries instead.

For `MapFixed`, the caller must provide exactly the declared entry count. The serializer does not enforce it; the deserializer always reads that many entries.

## Optional values

`Optional(node)` writes a 1-byte presence marker. A present value follows immediately after the marker.

```luau
local MaybeOwner = Types.Optional(Types.U32)

local absent = VoidSentryUltimate.Serialize(MaybeOwner, nil)
local present = VoidSentryUltimate.Serialize(MaybeOwner, 42)
```

## Strings and buffers

String lengths are byte lengths because the implementation uses Luau's `#string`, including for UTF-8 text. They are not character or code-point counts.

- `String` and `Buffer` use a 2-byte length prefix.
- `String8` and `Buffer8` use a 1-byte length prefix.
- `Buffer24` uses a 3-byte length prefix.
- `StringFixed(length)` and `BufferFixed(length)` have no length prefix.

Fixed strings and buffers require exactly the configured number of bytes from the caller. The library does not validate that requirement.

## Compatibility checklist

- Keep the same schema, including nested nodes, on every endpoint.
- Keep field names unchanged in structs; names determine sorted wire order.
- Version schemas when persisted data or network peers can outlive a deployment.
- Treat prefix limits as hard input constraints because the library does not check them.
- Do not deserialize untrusted or malformed data without an outer validation strategy.

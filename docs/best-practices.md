---
sidebar_position: 6
---

# Best practices

## Share one schema definition

Put each wire schema in a shared module and import it from every producer and consumer. A buffer carries no schema information, so a mismatch can silently reinterpret every following byte.

```luau
local Types = VoidSentryUltimate.Types

return Types.Struct({
	Sequence = Types.U32,
	SentAt = Types.F64,
	Value = Types.F32,
})
```

## Version persisted formats

Treat schemas as protocols. If a field or node changes, either keep decoding with the old schema or add an explicit version outside the payload.

```luau
local version = buffer.readu8(packet, 0)

if version == 1 then
	return VoidSentryUltimate.DeserializeWithOffset(MessageV1, packet, 1)
elseif version == 2 then
	return VoidSentryUltimate.DeserializeWithOffset(MessageV2, packet, 1)
else
	error("Unsupported message version")
end
```

Do not add a field to a `Struct` and expect older buffers to remain compatible. Struct keys are sorted, so adding or renaming a field can also move other fields in the wire order.

## Validate before serialization

VoidSentryUltimate deliberately strips validation. Enforce all application constraints before calling it:

- Integer values fit the selected signed or unsigned width.
- String and buffer byte lengths fit their prefixes.
- Fixed strings, buffers, arrays, and maps have exactly the configured lengths.
- `BoolPacked` receives exactly eight booleans.
- Required struct fields exist and have the expected types.
- Destination buffers have enough space before `Push`.

Validation is especially important at a trust boundary. Do not deserialize arbitrary client or external buffers without checking message size, version, authorization, and protocol limits around the call.

## Choose compact types from measured data

Use the smallest representation that safely covers real values:

- Prefer `String8`, `Array8`, `Map8`, and `Buffer8` only when payloads cannot exceed 255 bytes or entries.
- Use fixed variants when length is guaranteed by the protocol.
- Use `F16` or `F24` only after testing acceptable precision and range on representative values.
- Use integer vector variants only when every component fits the selected integer representation.
- Consider quaternion CFrames when their smaller representation fits your accuracy needs.

Reduced precision formats are lossy. Avoid unsupported assumptions about exact decimal error or range; test the values your application actually sends.

## Account for bytes, not characters

Luau's string length operator counts bytes. A UTF-8 string can use multiple bytes per visible character.

```luau
local text = "café"
print(#text)
```

Use `#text` when checking `String8`, `String`, or `StringFixed` limits.

## Plan deterministic bytes explicitly

`Struct` sorts its field names before use, but maps emit entries in table iteration order. Equivalent maps can therefore produce different byte sequences. For stable hashes, signatures, snapshots, or cache keys, sort entries yourself and serialize them as an array.

```luau
local Entry = Types.Struct({
	Key = Types.String8,
	Value = Types.U32,
})

local CanonicalEntries = Types.Array(Entry)
```

## Treat instance references as contextual

`Instance` and `Instance24` encode IDs from the module's `_VSID` maps, not object contents. The same instance must be mapped in the receiver's context. Replication timing matters on clients, and non-replicated instances cannot be resolved there.

Use `SerInstance` when the goal is to create a new object from selected properties rather than refer to an existing object.

## Size the scratch buffer once

`Serialize` and `SerializeWithOffset` first write into a reusable scratch buffer.
Its default `BIG_BUFFER_SIZE` is 1,000,000 bytes, which is also the default
maximum encoded payload size. If your protocol needs another limit, call
`SetWriteBufferSize` during initialization and include prefixes and nested
values when estimating the largest payload.

```luau
VoidSentryUltimate.SetWriteBufferSize(2_000_000)
```

## Use `Push` for known offsets

Prefer `Push` when you have already allocated a destination buffer and know
where each fixed-layout field belongs. It avoids allocating a separate result,
but it does not grow the destination or tell you the ending cursor.

```luau
local packet = buffer.create(6)
VoidSentryUltimate.Push(Types.U16, packetType, packet, 0)
VoidSentryUltimate.Push(Types.U32, sequence, packet, 2)
```

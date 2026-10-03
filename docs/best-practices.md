---
sidebar_position: 6
---

# Best practices

## Share one schema definition

Put each wire schema in a shared module and import it from every producer and consumer. A buffer carries no schema information, so a mismatch can silently reinterpret every following byte.

```luau
local Schema = VoidSentryUltimate.Schema

return Schema {
	Sequence = Types.U32,
	SentAt = Types.F64,
	Value = Types.F32,
}
```

## Version persisted formats

Treat schemas as protocols. If a field or node changes, keep decoding with the old schema, rewrite the buffer with [`Migrate`](./schemas.md#migrating-old-buffers), or add an explicit version outside the payload.

```luau
local version = buffer.readu8(packet, 0)

if version == 1 then
	return SchemaV1.DeserializeWithOffset(packet, 1)
elseif version == 2 then
	return SchemaV2.DeserializeWithOffset(packet, 1)
else
	error("Unsupported message version")
end
```

Do not add a field to a `Schema` and expect older buffers to remain compatible. Struct keys are sorted, so adding or renaming a field can also move other fields in the wire order.

## Choose compact types from measured data

Use the smallest representation that safely covers real values:

- Prefer `String8`, `Array8`, `Map8`, and `Buffer8` only when payloads cannot exceed 255 bytes or entries.
- Use `String24` or `Buffer24` when a payload can exceed 65,535 bytes.
- Use fixed variants when length is guaranteed by the protocol.
- Use `F16` or `F24` only after testing acceptable precision and range on representative values.
- Use integer vector variants only when every component fits the selected integer representation.
- Consider quaternion CFrames when their smaller representation fits your accuracy needs.
- Use `CFrameQuantF16` / `CFrameQuant8F16` or `UDim2Quant` only after measuring orientation or scale error on representative values.

Reduced precision formats are lossy. Avoid unsupported assumptions about exact decimal error or range; test the values your application actually sends.

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
where each fixed-layout field belongs. It avoids allocating a separate result
buffer and returns the ending cursor. The destination is not grown for you.

```luau
local packet = buffer.create(6)
local cursor = VoidSentryUltimate.Push(Types.U16, packetType, packet, 0)
VoidSentryUltimate.Push(Types.U32, sequence, packet, cursor)
```

`Deserialize`, `DeserializeWithOffset`, and `Push` all return the final cursor.
You can ignore the second return from deserialize calls when you only need the value.


## Prefer `Schema` over `Struct`

`Schema` type is slightly faster than `Struct` type, easier and more convenient to use

The only reason to use structs is for nested definitions (Schema cannot be nested)
```luau
local PlayerData = Schema {
	Name = Types.String8,
	Id = Types.UInt,
	Builds = Types.Array(Types.Struct {
		Id = Types.UInt,
		CFrame = Types.QCFrame,
	})
}
```
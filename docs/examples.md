---
sidebar_position: 5
---

# Examples

## Round trip a struct

```luau
local VoidSentryUltimate = require(path.to.VoidSentryUltimate)
local Types = VoidSentryUltimate.Types

local Profile = Types.Struct({
	Coins = Types.U32,
	DisplayName = Types.String8,
	EquippedItem = Types.Optional(Types.U16),
})

local original = {
	Coins = 12_500,
	DisplayName = "Elentium",
	EquippedItem = 17,
}

local bytes = VoidSentryUltimate.Serialize(Profile, original)
local restored = VoidSentryUltimate.Deserialize(Profile, bytes)

print(restored.DisplayName, restored.Coins, restored.EquippedItem)
```

## Encode a compact inventory

When item identifiers fit from 0 through 255, an array of `U8` values keeps
both the element representation and count compact:

```luau
local Inventory = Types.Array8(Types.U8)
local bytes = VoidSentryUltimate.Serialize(Inventory, { 4, 9, 23, 71 })
local itemIds = VoidSentryUltimate.Deserialize(Inventory, bytes)
```

`Array8` adds a one-byte element count, and every `U8` item adds one byte. Use a
wider count or item node if either limit can be exceeded.

## Send a RemoteEvent payload

Define the schema in a shared module so the server and client cannot accidentally drift.

```luau
local VoidSentryUltimate = require(path.to.VoidSentryUltimate)
local Types = VoidSentryUltimate.Types

local DamageMessage = Types.Struct({
	Amount = Types.U16,
	Critical = Types.Bool,
	Origin = Types.VectorF24,
	Target = Types.Instance,
})

return DamageMessage
```

Serialize on the server:

```luau
local bytes = VoidSentryUltimate.Serialize(DamageMessage, {
	Amount = 25,
	Critical = false,
	Origin = Vector3.new(10, 2, -4),
	Target = targetPart,
})

DamageEvent:FireClient(player, bytes)
```

Deserialize on the client with the same schema:

```luau
DamageEvent.OnClientEvent:Connect(function(bytes: buffer)
	local message = VoidSentryUltimate.Deserialize(DamageMessage, bytes)
	print(message.Target, message.Amount)
end)
```

`Types.Instance` depends on the Roblox module's `_VSID` maps. Use `Types.SerInstance` instead only when the receiver should create a new instance from serialized properties.

## Serialize an instance by value

```luau
local SerializablePart = Types.SerInstance("Part", {
	Anchored = Types.Bool,
	Color = Types.Color3,
	Name = Types.String8,
	Position = Types.Vector,
	Size = Types.Vector,
})

local bytes = VoidSentryUltimate.Serialize(SerializablePart, workspace.SourcePart)
local copiedPart = VoidSentryUltimate.Deserialize(SerializablePart, bytes)
copiedPart.Parent = workspace
```

Deserialization creates a new `Part` and assigns the listed properties. Parent is not included unless it is explicitly part of the schema.

## Pack eight flags

```luau
local flags = {
	true,
	true,
	false,
	false,
	true,
	false,
	false,
	true,
}

local oneByte = VoidSentryUltimate.Serialize(Types.BoolPacked, flags)
local restoredFlags = VoidSentryUltimate.Deserialize(Types.BoolPacked, oneByte)
```

`BoolPacked` always represents exactly eight booleans.

## Choose F24 or F32 deliberately

For three-dimensional positions, `VectorF24` uses 9 bytes while `Vector` uses
12 bytes:

```luau
local CompactPosition = Types.VectorF24
local ExactF32Position = Types.Vector

local compact = VoidSentryUltimate.Serialize(CompactPosition, position)
local regular = VoidSentryUltimate.Serialize(ExactF32Position, position)
```

`VectorF24` is lossy and has less range and precision. Round-trip values from
your actual game and compare them against your accepted positional tolerance
before choosing it. Use `Vector` when normal F32 behavior is required.

## Quantize UI scales and compact CFrames

`UDim2Quant` stores only scale, mapped into 16-bit values over a chosen range.
`CFrameQuantF16` and `CFrameQuant8F16` store `F16` position plus quantized Euler
angles:

```luau
local Scale = Types.UDim2Quant(0, 1)
local CompactCFrame = Types.CFrameQuantF16
local SmallerCFrame = Types.CFrameQuant8F16

local scaleBytes = VoidSentryUltimate.Serialize(Scale, UDim2.fromScale(0.5, 0.25))
local cframeBytes = VoidSentryUltimate.Serialize(CompactCFrame, cframe)
```

Decoded `UDim2Quant` offsets are zero. `CFrameQuant8F16` is smaller (9 bytes)
than `CFrameQuantF16` (12 bytes) and coarser in orientation.

## Use a fixed-size record

```luau
local DigestRecord = Types.Struct({
	Digest = Types.BufferFixed(16),
	Label = Types.StringFixed(8),
	Samples = Types.ArrayFixed(Types.I16, 4),
})

local bytes = VoidSentryUltimate.Serialize(DigestRecord, {
	Digest = digestBuffer,
	Label = "SENSOR01",
	Samples = { -2, 4, 8, 16 },
})
```

`Digest` must be exactly 16 bytes, `Label` exactly 8 bytes, and `Samples` exactly four elements. No lengths are written or validated.

## Preserve an application header

```luau
local Payload = Types.Struct({
	Id = Types.U32,
	Message = Types.String8,
})

local bytes = VoidSentryUltimate.SerializeWithOffset(Payload, {
	Id = 7,
	Message = "ready",
}, 2)

buffer.writeu8(bytes, 0, 1)
buffer.writeu8(bytes, 1, 9)

local decoded = VoidSentryUltimate.DeserializeWithOffset(Payload, bytes, 2)
```

The first two bytes are initially zero because `SerializeWithOffset` allocates a new zero-filled buffer of `offset + payload length`.
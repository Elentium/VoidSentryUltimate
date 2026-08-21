---
sidebar_position: 4
---

# Type catalog

All public nodes are under `VoidSentryUltimate.Types`. Sizes below are wire sizes. Variable-size nodes include the stated prefix plus their payload.

## Numbers

- `U8`, `I8`: 1-byte unsigned or signed integer.
- `U16`, `I16`: 2-byte unsigned or signed integer.
- `U24`, `I24`: 3-byte unsigned or signed integer.
- `U32`, `I32`: 4-byte unsigned or signed integer.
- `F16`: 2-byte reduced-precision float.
- `F24`: 3-byte reduced-precision float.
- `F32`: 4-byte float.
- `F64`: 8-byte float.

`F16` uses less space than `F24`, with less precision and range. `F24` retains more of an `F32` value while still saving one byte. Both are lossy conversions; use `F32` or `F64` when reduced precision is unacceptable. The implementation does not promise application-specific error bounds, so test representative values before choosing a reduced format.

## Booleans

- `Bool`: one boolean in 1 byte.
- `BoolPacked`: exactly 8 booleans packed into 1 byte, in array positions 1 through 8.

```luau
local flags = {
	true,
	false,
	true,
	false,
	true,
	false,
	true,
	false,
}

local bytes = VoidSentryUltimate.Serialize(Types.BoolPacked, flags)
```

## Strings

- `String`: 2-byte unsigned byte-length prefix, then 0 to 65,535 bytes.
- `String8`: 1-byte unsigned byte-length prefix, then 0 to 255 bytes.
- `StringFixed(length)`: exactly `length` bytes with no prefix.

The prefix records bytes, not UTF-8 characters. `StringFixed` requires the caller to provide exactly the configured byte length.

## Buffers

- `Buffer`: 2-byte unsigned length prefix, then 0 to 65,535 bytes.
- `Buffer8`: 1-byte unsigned length prefix, then 0 to 255 bytes.
- `Buffer24`: 3-byte unsigned length prefix, then 0 to 16,777,215 bytes.
- `BufferFixed(length)`: exactly `length` bytes with no prefix.

## Collections and composition

- `Array(node)`: 2-byte element-count prefix.
- `Array8(node)`: 1-byte element-count prefix.
- `Array24(node)`: 3-byte element-count prefix.
- `ArrayFixed(node, length)`: no prefix; exactly `length` elements.
- `Map(keyNode, valueNode)`: 2-byte entry-count prefix.
- `Map8(keyNode, valueNode)`: 1-byte entry-count prefix.
- `Map24(keyNode, valueNode)`: 3-byte entry-count prefix.
- `MapFixed(keyNode, valueNode, length)`: no prefix; exactly `length` entries.
- `Struct(fields)`: fields only, with no struct prefix.
- `Optional(node)`: 1-byte presence marker, followed by the value only when present.

The 1-, 2-, and 3-byte count prefixes represent up to 255, 65,535, and 16,777,215 entries respectively. Fixed variants do not encode a count and perform no exact-length validation.

## Vectors

The Roblox module exposes `Vector3` nodes:

- `Vector`: three `F32` components, 12 bytes.
- `VectorF16`: three `F16` components, 6 bytes.
- `VectorF24`: three `F24` components, 9 bytes.
- `VectorU8`, `VectorI8`: three integer components, 3 bytes.
- `VectorU16`, `VectorI16`: three integer components, 6 bytes.
- `VectorU24`, `VectorI24`: three integer components, 9 bytes.

It also exposes `Vector2` nodes:

- `Vector2`: two `F32` components, 8 bytes.
- `Vector2F16`: two `F16` components, 4 bytes.
- `Vector2F24`: two `F24` components, 6 bytes.
- `Vector2U8`, `Vector2I8`: two integer components, 2 bytes.
- `Vector2U16`, `Vector2I16`: two integer components, 4 bytes.
- `Vector2U24`, `Vector2I24`: two integer components, 6 bytes.

The pure Luau module exposes the `Vector`, `VectorF16`, `VectorF24`, `VectorU8`, `VectorI8`, `VectorU16`, `VectorI16`, `VectorU24`, and `VectorI24` names for Luau's `vector` type. It has vector support but no Roblox-only types.

## Roblox UI and value types

- `UDim2`: four `F32` components, 16 bytes.
- `UDim2Scale`: the two scale components as `F32`, 8 bytes; decoded offsets are zero.
- `UDim2Offset`: the two offset components as `F32`, 8 bytes; decoded scales are zero.
- `UDim2OffsetI16`: the two offset components as `I16`, 4 bytes; decoded scales are zero.
- `UDim2ScaleF24`: the two scale components as `F24`, 6 bytes; decoded offsets are zero.
- `Color3`: RGB channels as three bytes, 3 bytes.
- `Enum(enumType)`: an enum item's numeric value in 2 bytes.
- `Enum8(enumType)`: an enum item's numeric value in 1 byte.

## Roblox CFrames

- `CFrame`: position plus a 3-by-3 rotation matrix using 12 `F32` values, 48 bytes.
- `CFrameF16`: the same 12 components using `F16`, 24 bytes.
- `CFrameF24`: the same 12 components using `F24`, 36 bytes.
- `QCFrame`: position plus quaternion using seven `F32` values, 28 bytes.
- `QCFrameF16`: the same seven values using `F16`, 14 bytes.
- `QCFrameF24`: the same seven values using `F24`, 21 bytes.

The compressed variants trade precision for smaller payloads. Quaternion variants are smaller than matrix variants but reconstruct orientation from quaternion components.

## Roblox instances

- `Instance`: a 2-byte `_VSID` reference ID.
- `Instance24`: a 3-byte `_VSID` reference ID.
- `SerInstance(className, schema)`: serializes the listed properties with no class or length prefix; deserialization calls `Instance.new(className)` and assigns those properties.

For `Instance` and `Instance24`, module initialization maintains maps between instances and IDs. On the server, existing and newly added descendants receive a numeric `_VSID` attribute and IDs from removed descendants can be reused. On the client, existing and newly added descendants are observed and their replicated `_VSID` attributes populate the local maps. The referenced instance must be present and reachable in the current context.

`SerInstance` is different: it does not serialize a reference and does not use `_VSID`. It creates a new instance during deserialization. Its property names are sorted when the node is created, and only the listed property values are written.

## Pure Luau availability

`LuauVS.luau` exposes exactly these public `Types` names:

- Numbers and booleans: `U8`, `I8`, `U16`, `I16`, `U24`, `I24`, `U32`, `I32`, `F16`, `F24`, `F32`, `F64`, `Bool`, `BoolPacked`.
- Strings and buffers: `String`, `String8`, `StringFixed`, `Buffer`, `Buffer8`, `Buffer24`, `BufferFixed`.
- Collections: `Array`, `Array8`, `Array24`, `ArrayFixed`, `Map`, `Map8`, `Map24`, `MapFixed`, `Struct`, `Optional`.
- Vectors: `Vector`, `VectorF16`, `VectorF24`, `VectorU8`, `VectorI8`, `VectorU16`, `VectorI16`, `VectorU24`, `VectorI24`.

The Roblox module contains all names above plus the Roblox-only names documented in this page.

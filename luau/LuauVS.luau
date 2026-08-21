--!native
--!optimize 2
--[[
    VoidSentryUltimate 
    [ Pure luau version ]
    [ V1.0.0 ]
    [ by IAMNOTULTRA3 a.k.a Elentium, Elite ]
    [ Apache-2.0 License ]

    Efficient SerDes library

    Docs: https://Elentium.github.io/VoidSentryUltimate
]]

--- Schema-based, validation-free serialization for Luau.
---
--- Build a `SerdesNode` from `VoidSentryUltimate.Types`, then use the same
--- schema to serialize and deserialize a value. The file does not include Roblox types.
---
--- @class VoidSentryUltimate
---------------------------------------------------------
-- CONSTANTS
---------------------------------------------------------
const SER = 1 -- index of Ser function
const DES = 2 -- index of Des function
const BIG_BUFFER_SIZE = 1_000_000 -- size of big scratch buffer (this also means the max serialize bytes)

---------------------------------------------------------
-- MODULE
---------------------------------------------------------
const VoidSentryUltimate = {} :: Lib
--- Schema type nodes from `VoidSentryUltimate.Types`.
--- @class Types
const Types = {}
VoidSentryUltimate.Types = Types

---------------------------------------------------------
-- TYPES
---------------------------------------------------------
export type Ser<T> = (T) -> ()
export type Des<T> = () -> T

export type SerdesNode<T> = {
	-- [1] = Ser
	-- [2] = Des
	[number]: Ser<T> | Des<T>,
	_T: T | any,
}

-- Returns a non-any type from the Dual union
-- This type function is made because for some reason .Deserialize return type is any | T
type function GetProperTypeFromUnion(Union: type)
    if Union.tag ~= "union" then
        return Union
    end

    const Components = Union:components()
    const First = Components[1]
    if First.tag == "any" then
        return Components[2] :: any -- any cast because of a luau bug
    end

    return First :: any
end

export type Lib = {
    Serialize: <T>(Node: SerdesNode<T>, Data: T) -> buffer,
    SerializeWithOffset: <T>(Node: SerdesNode<T>, Data: T, Offset: number) -> buffer,
    Deserialize: <T>(Node: SerdesNode<T>, Buffer: buffer) -> GetProperTypeFromUnion<T>,
    DeserializeWithOffset: <T>(Node: SerdesNode<T>, Buffer: buffer, Offset: number) -> GetProperTypeFromUnion<T> & { [string]: any },
    Push: <T>(Node: SerdesNode<T>, Data: T, Buffer: buffer, Offset: number?) -> (),
    SetWriteBufferSize: (NewSize: number) -> (),

    Types: {
        U8: SerdesNode<number>,
        I8: SerdesNode<number>,
        U16: SerdesNode<number>,
        I16: SerdesNode<number>,
        U32: SerdesNode<number>,
        I32: SerdesNode<number>,
        U24: SerdesNode<number>,
        I24: SerdesNode<number>,
        F16: SerdesNode<number>,
        F24: SerdesNode<number>,
        F32: SerdesNode<number>,
        F64: SerdesNode<number>,
        Bool: SerdesNode<boolean>,
        BoolPacked: SerdesNode<{ boolean }>,
        String: SerdesNode<string>,
        String8: SerdesNode<string>,
        StringFixed: (Length: number) -> SerdesNode<string>,
        Buffer: SerdesNode<buffer>,
        Buffer8: SerdesNode<buffer>,
        Buffer24: SerdesNode<buffer>,
        BufferFixed: (Length: number) -> SerdesNode<buffer>,
        Vector: SerdesNode<vector>,
        VectorF16: SerdesNode<vector>,
        VectorF24: SerdesNode<vector>,
        VectorU8: SerdesNode<vector>,
        VectorI8: SerdesNode<vector>,
        VectorU16: SerdesNode<vector>,
        VectorI16: SerdesNode<vector>,
        VectorU24: SerdesNode<vector>,
        VectorI24: SerdesNode<vector>,
        Array: <T>(Node: SerdesNode<T>) -> SerdesNode<{ T }>,
        Array8: <T>(Node: SerdesNode<T>) -> SerdesNode<{ T }>,
        Array24: <T>(Node: SerdesNode<T>) -> SerdesNode<{ T }>,
        ArrayFixed: <T>(Node: SerdesNode<T>, Length: number) -> SerdesNode<{ T }>,
        Struct: <T>(Tbl: T & { [string]: SerdesNode<any> }) -> SerdesNode<GetTypeFromTypeNodes<T>>,
        Map: <K, V>(KeyNode: SerdesNode<K>, ValueNode: SerdesNode<V>) -> SerdesNode<{ [K]: V }>,
        Map8: <K, V>(KeyNode: SerdesNode<K>, ValueNode: SerdesNode<V>) -> SerdesNode<{ [K]: V }>,
        Map24: <K, V>(KeyNode: SerdesNode<K>, ValueNode: SerdesNode<V>) -> SerdesNode<{ [K]: V }>,
        MapFixed: <K, V>(KeyNode: SerdesNode<K>, ValueNode: SerdesNode<V>, Length: number) -> SerdesNode<{ [K]: V }>,
        Optional: <T>(Node: SerdesNode<T>) -> SerdesNode<T?>,
    },
}

export type function GetTypeFromTypeNodes(Struct: type)
    if Struct.tag ~= "table" then
        error(`Argument #1 must be a table, got {Struct.tag}`)
    end

    const Tbl = types.newtable()
    const TKey = types.singleton("_T")
    for Key, Value in Struct:properties() do
        const Node = Value.read or Value.write :: type
        const T = Node:readproperty(TKey)
        if not T then
            error("_T field not found in Node")
        end

        Tbl:setproperty(Key, T:components()[1])
    end

    return Tbl
end

---------------------------------------------------------
-- STATE
---------------------------------------------------------
local WriteBuffer = buffer.create(BIG_BUFFER_SIZE) -- scratch buffer that is used during serialization
const FloatConverter = buffer.create(4) -- used to convert f32 to smaller precision version
local Cursor: number = 0
local ReadBuffer: buffer? = nil

---------------------------------------------------------
-- LOCALIZING BUILTINS
---------------------------------------------------------
const CreateTable = table.create
const Ipairs = ipairs
const MathHuge = math.huge
const NMathHuge = -math.huge

---------------------------------------------------------
-- NODES
---------------------------------------------------------
--- Signed 8-bit integer. 1 byte.
--- @within Types
--- @tag Primitives
--- @prop I8 SerdesNode<number>

const I8: SerdesNode<number> = {} -- Signed 8-bit integer

do
	const function I8Ser(Value: number)
        const Cur = Cursor
		buffer.writei8(WriteBuffer, Cur, Value)
		Cursor = Cur + 1
	end

	const function I8Des(): number
        const Cur = Cursor
		const Value = buffer.readi8(ReadBuffer :: buffer, Cur)
		Cursor = Cur + 1
		return Value
	end

	I8[SER] = I8Ser
	I8[DES] = I8Des
end

--- Unsigned 8-bit integer. 1 byte.
--- @within Types
--- @tag Primitives
--- @prop U8 SerdesNode<number>

const U8: SerdesNode<number> = {} -- Unsigned 8-bit integer

do
	const function U8Ser(Value: number)
        const Cur = Cursor
		buffer.writeu8(WriteBuffer, Cur, Value)
		Cursor = Cur + 1
	end

	const function U8Des(): number
        const Cur = Cursor
		const Value = buffer.readu8(ReadBuffer :: buffer, Cur)
		Cursor = Cur + 1
		return Value
	end

	U8[SER] = U8Ser
	U8[DES] = U8Des
end

--- Unsigned 16-bit integer. 2 bytes.
--- @within Types
--- @tag Primitives
--- @prop U16 SerdesNode<number>

const U16: SerdesNode<number> = {} -- Unsigned 16-bit integer

do
	const function U16Ser(Value: number)
		const Cur = Cursor
		buffer.writeu16(WriteBuffer, Cur, Value)
		Cursor = Cur + 2
	end

	const function U16Des(): number
		const Cur = Cursor
		const Value = buffer.readu16(ReadBuffer :: buffer, Cur)
		Cursor = Cur + 2
		return Value
	end

	U16[SER] = U16Ser
	U16[DES] = U16Des
end

--- Signed 16-bit integer. 2 bytes.
--- @within Types
--- @tag Primitives
--- @prop I16 SerdesNode<number>

const I16: SerdesNode<number> = {} -- Signed 16-bit integer

do
	const function I16Ser(Value: number)
		const Cur = Cursor
		buffer.writei16(WriteBuffer, Cur, Value)
		Cursor = Cur + 2
	end

	const function I16Des(): number
		const Cur = Cursor
		const Value = buffer.readi16(ReadBuffer :: buffer, Cur)
		Cursor = Cur + 2
		return Value
	end

	I16[SER] = I16Ser
	I16[DES] = I16Des
end

--- Unsigned 32-bit integer. 4 bytes.
--- @within Types
--- @tag Primitives
--- @prop U32 SerdesNode<number>

const U32: SerdesNode<number> = {} -- Unsigned 32-bit integer

do
	const function U32Ser(Value: number)
		const Cur = Cursor
		buffer.writeu32(WriteBuffer, Cur, Value)
		Cursor = Cur + 4
	end

	const function U32Des(): number
		const Cur = Cursor
		const Value = buffer.readu32(ReadBuffer :: buffer, Cur)
		Cursor = Cur + 4
		return Value
	end

	U32[SER] = U32Ser
	U32[DES] = U32Des
end

--- Signed 32-bit integer. 4 bytes.
--- @within Types
--- @tag Primitives
--- @prop I32 SerdesNode<number>

const I32: SerdesNode<number> = {} -- Signed 32-bit integer

do
	const function I32Ser(Value: number)
		const Cur = Cursor
		buffer.writei32(WriteBuffer, Cur, Value)
		Cursor = Cur + 4
	end

	const function I32Des(): number
		const Cur = Cursor
		const Value = buffer.readi32(ReadBuffer :: buffer, Cur)
		Cursor = Cur + 4
		return Value
	end

	I32[SER] = I32Ser
	I32[DES] = I32Des
end

--- IEEE float. 4 bytes.
--- @within Types
--- @tag Primitives
--- @prop F32 SerdesNode<number>

const F32: SerdesNode<number> = {} -- IEEE-754 Single Precision Float

do
	const function F32Ser(Value: number)
		const Cur = Cursor
		buffer.writef32(WriteBuffer, Cur, Value)
		Cursor = Cur + 4
	end

	const function F32Des(): number
		const Cur = Cursor
		const Value = buffer.readf32(ReadBuffer :: buffer, Cur)
		Cursor = Cur + 4
		return Value
	end

	F32[SER] = F32Ser
	F32[DES] = F32Des
end

--- IEEE double. 8 bytes.
--- @within Types
--- @tag Primitives
--- @prop F64 SerdesNode<number>

const F64: SerdesNode<number> = {} -- IEEE-754 Double Precision Float

do
	const function F64Ser(Value: number)
		const Cur = Cursor
		buffer.writef64(WriteBuffer, Cur, Value)
		Cursor = Cur + 8
	end

	const function F64Des(): number
		const Cur = Cursor
		const Value = buffer.readf64(ReadBuffer :: buffer, Cur)
		Cursor = Cur + 8
		return Value
	end

	F64[SER] = F64Ser
	F64[DES] = F64Des
end

--- UTF-8 string with a `u16` byte-length prefix.
--- @within Types
--- @tag Special
--- @prop String SerdesNode<string>

const String: SerdesNode<string> = {} -- String  (16 bits for length, meaning max characters size is 65535)

do
	const function StringSer(Value: string)
        const Len = #Value
        local Cur = Cursor
        const Buf = WriteBuffer
        buffer.writeu16(Buf, Cur, Len)
        Cur += 2
		buffer.writestring(Buf, Cur, Value)
		Cursor = Cur + Len
	end

	const function StringDes(): string
        local Cur = Cursor
        const Buf = ReadBuffer
		const Len = buffer.readu16(Buf :: buffer, Cur)
		Cur += 2
        const Value = buffer.readstring(Buf :: buffer, Cur, Len)
        Cursor = Cur + Len
		return Value
	end

	String[SER] = StringSer
	String[DES] = StringDes
end

--- UTF-8 string with a `u8` byte-length prefix.
--- @within Types
--- @tag Special
--- @prop String8 SerdesNode<string>

const String8: SerdesNode<string> = {} -- String8 (8 bits for length, meaning max characters size is 255)

do
	const function String8Ser(Value: string)
        const Len = #Value
        const Buf = WriteBuffer
        local Cur = Cursor
        buffer.writeu8(Buf, Cur, Len)
        Cur += 1
		buffer.writestring(Buf, Cur, Value)
		Cursor = Cur + Len
	end

	const function String8Des(): string
        const Buf = ReadBuffer
        local Cur = Cursor
		const Len = buffer.readu8(Buf :: buffer, Cur)
		Cur += 1
        const Value = buffer.readstring(Buf :: buffer, Cur, Len)
        Cursor = Cur + Len
		return Value
	end

	String8[SER] = String8Ser
	String8[DES] = String8Des
end

-- StringFixed (fixed length)
--- Fixed-length UTF-8 string with no length prefix.
--- @within Types
--- @tag Special
--- @function StringFixed
--- @param length number -- Exact byte length on the wire.
--- @return SerdesNode<string>

const function StringFixed(Length: number): SerdesNode<string>
    const StringFixedNode: SerdesNode<string> = {}

    const function StringFixedSer(Value: string)
        const Cur = Cursor
		buffer.writestring(WriteBuffer, Cur, Value)
		Cursor = Cur + Length
	end

	const function StringFixedDes(): string
        const Buf = ReadBuffer
        const Cur = Cursor
        const Value = buffer.readstring(Buf :: buffer, Cur, Length)
        Cursor = Cur + Length
		return Value
	end

	StringFixedNode[SER] = StringFixedSer
	StringFixedNode[DES] = StringFixedDes

    return StringFixedNode
end

-- Array (16 bits for length write, meaning max amount of elements in the array is 65535)
--- Array with a `u16` element-count prefix.
--- @within Types
--- @tag Collections
--- @function Array
--- @param node SerdesNode<T> -- Element schema.
--- @return SerdesNode<{ T }>

const function Array<T>(Node: SerdesNode<T>): SerdesNode<{ T }>
    const ArrayNode: SerdesNode<{ T }> = {}

    const Ser = Node[SER] :: Ser<T>
    const Des = Node[DES] :: Des<T>

    const function ArraySer(Array: { T })
        const Len = #Array
        const Cur = Cursor
        buffer.writeu16(WriteBuffer, Cur, Len)
        Cursor = Cur + 2
        for _, Value in Ipairs(Array) do
            Ser(Value)
        end
    end

    const function ArrayDes(): { T }
        const Cur = Cursor
        const Len = buffer.readu16(ReadBuffer :: buffer, Cur)
        const Array = CreateTable<<T>>(Len)
        Cursor = Cur + 2
        for i = 1, Len do
            Array[i] = Des()
        end
        return Array
    end

    ArrayNode[SER] = ArraySer
    ArrayNode[DES] = ArrayDes

    return ArrayNode
end

-- Array8 (8 bits for length write, meaning max amount of elements in the array is 255)
--- Array with a `u8` element-count prefix.
--- @within Types
--- @tag Collections
--- @function Array8
--- @param node SerdesNode<T> -- Element schema.
--- @return SerdesNode<{ T }>

const function Array8<T>(Node: SerdesNode<T>): SerdesNode<{ T }>
    const Array8Node: SerdesNode<{ T }> = {}

    const Ser = Node[SER] :: Ser<T>
    const Des = Node[DES] :: Des<T>

    const function Array8Ser(Array: { T })
        const Cur = Cursor
        const Len = #Array
        buffer.writeu8(WriteBuffer, Cur, Len)
        Cursor = Cur + 1
        for _, Value in Ipairs(Array) do
            Ser(Value)
        end
    end

    const function Array8Des(): { T }
        const Cur = Cursor
        const Len = buffer.readu8(ReadBuffer :: buffer, Cur)
        const Array = CreateTable<<T>>(Len)
        Cursor = Cur + 1
        for i = 1, Len do
            Array[i] = Des()
        end
        return Array
    end

    Array8Node[SER] = Array8Ser
    Array8Node[DES] = Array8Des

    return Array8Node
end

-- Array24 (24 bits for length write, meaning max amount of elements in the array is 16_777_215)
--- Array with a `u24` element-count prefix.
--- @within Types
--- @tag Collections
--- @function Array24
--- @param node SerdesNode<T> -- Element schema.
--- @return SerdesNode<{ T }>

const function Array24<T>(Node: SerdesNode<T>): SerdesNode<{ T }>
    const Array24Node: SerdesNode<{ T }> = {}

    const Ser = Node[SER] :: Ser<T>
    const Des = Node[DES] :: Des<T>

    const function Array24Ser(Array: { T })
        const Len = #Array
        local Cur = Cursor
        const Buf = WriteBuffer
        buffer.writeu16(Buf, Cur, bit32.band(Len, 0xFFFF))
        buffer.writeu8(Buf, Cur + 2, bit32.band(bit32.rshift(Len, 16), 0xFF))
        Cursor = Cur + 3
        for _, Value in Ipairs(Array) do
            Ser(Value)
        end
    end

    const function Array24Des(): { T }
        local Cur = Cursor
        const Buf = ReadBuffer :: buffer
        const b1: number = buffer.readu16(Buf, Cur)
        const b2: number = buffer.readu8(Buf, Cur + 2)
        const Len = bit32.bor(b1, bit32.lshift(b2, 16))
        const Array = CreateTable<<T>>(Len)
        Cursor = Cur + 3
        for i = 1, Len do
            Array[i] = Des()
        end
        return Array
    end

    Array24Node[SER] = Array24Ser
    Array24Node[DES] = Array24Des

    return Array24Node
end

-- Struct (Pretty straightforward)
--- Struct schema. Field names are sorted lexicographically on the wire.
--- @within Types
--- @tag Collections
--- @function Struct
--- @param fields {[string]: SerdesNode<any>} -- Field schemas keyed by name.
--- @return SerdesNode<any>

const function Struct<T>(Tbl: T & { [string]: SerdesNode<any> }): SerdesNode<GetTypeFromTypeNodes<T>>
    const StructNode: SerdesNode<T> = {}

    const Keys = {}
    local Idx = 0
    for Key in Tbl :: { [string]: SerdesNode<any> } do
        Idx += 1
        Keys[Idx] = Key
    end
    table.sort(Keys)

    const Writes = CreateTable<<Ser<any>>>(Idx)
    const Reads = CreateTable<<Des<any>>>(Idx)

    for i, Key in Ipairs(Keys) do
        const Node = Tbl[Key]
        Writes[i] = Node[SER] :: Ser<any>
        Reads[i] = Node[DES] :: Des<any>
    end

    const function StructSer(Struct: T & { [string]: SerdesNode<any> })
        for i, Key in Ipairs(Keys) do
            Writes[i](Struct[Key])
        end
    end

    const function StructDes(): T
        const Result = {}
        for i, Key in Ipairs(Keys) do
            Result[Key] = Reads[i]()
        end
        return Result
    end

    StructNode[SER] = StructSer
    StructNode[DES] = StructDes

    return StructNode
end

--- `vector` with three `f32` components. 12 bytes.
--- @within Types
--- @tag Vectors
--- @prop Vector SerdesNode<vector>

const Vector: SerdesNode<vector> = {} -- Vector (4x3 bytes, each element is F32)
do
    const function VectorSer(Value: vector)
        local Cur = Cursor
        const Buf = WriteBuffer
        buffer.writef32(Buf, Cur, Value.x)
        buffer.writef32(Buf, Cur + 4, Value.y)
        buffer.writef32(Buf, Cur + 8, Value.z)
        Cursor = Cur + 12
    end

    const function VectorDes(): vector
        local Cur = Cursor
        const Buf = ReadBuffer :: buffer
        const x = buffer.readf32(Buf, Cur)
        const y = buffer.readf32(Buf, Cur + 4)
        const z = buffer.readf32(Buf, Cur + 8)
        Cursor = Cur + 12

        return vector.create(x, y, z)
    end

    Vector[SER] = VectorSer
    Vector[DES] = VectorDes
end

-- Map (16 bits for length write, meaning max amount of elements in the map is 65535)
--- Map with a `u16` entry-count prefix.
--- @within Types
--- @tag Collections
--- @function Map
--- @param keyNode SerdesNode<K> -- Key schema.
--- @param valueNode SerdesNode<V> -- Value schema.
--- @return SerdesNode<{ [K]: V }>

const function Map<K, V>(KeyNode: SerdesNode<K>, ValueNode: SerdesNode<V>): SerdesNode<{ [K]: V }>
    const MapNode: SerdesNode<{ [K]: V }> = {}

    const KeySer = KeyNode[SER] :: Ser<K>
    const KeyDes = KeyNode[DES] :: Des<K>

    const ValueSer = ValueNode[SER] :: Ser<V>
    const ValueDes = ValueNode[DES] :: Des<V>

    const function MapSer(Map: { [K]: V })
        const Cur = Cursor
        local Len = 0
        Cursor = Cur + 2
        for Key, Value in Map do
            Len += 1
            KeySer(Key)
            ValueSer(Value)
        end
        buffer.writeu16(WriteBuffer, Cur, Len)
    end

    const function MapDes(): { [K]: V }
        const Cur = Cursor
        const Len = buffer.readu16(ReadBuffer :: buffer, Cur)
        const Map = {}
        Cursor = Cur + 2
        for _ = 1, Len do
            Map[KeyDes()] = ValueDes()
        end
        return Map
    end

    MapNode[SER] = MapSer
    MapNode[DES] = MapDes

    return MapNode
end

-- Map8 (8 bits for length write, meaning max amount of elements in the map is 255)
--- Map with a `u8` entry-count prefix.
--- @within Types
--- @tag Collections
--- @function Map8
--- @param keyNode SerdesNode<K> -- Key schema.
--- @param valueNode SerdesNode<V> -- Value schema.
--- @return SerdesNode<{ [K]: V }>

const function Map8<K, V>(KeyNode: SerdesNode<K>, ValueNode: SerdesNode<V>): SerdesNode<{ [K]: V }>
    const Map8Node: SerdesNode<{ [K]: V }> = {}

    const KeySer = KeyNode[SER] :: Ser<K>
    const KeyDes = KeyNode[DES] :: Des<K>

    const ValueSer = ValueNode[SER] :: Ser<V>
    const ValueDes = ValueNode[DES] :: Des<V>

    const function Map8Ser(Map: { [K]: V })
        const Cur = Cursor
        local Len = 0
        Cursor = Cur + 1
        for Key, Value in Map do
            Len += 1
            KeySer(Key)
            ValueSer(Value)
        end
        buffer.writeu8(WriteBuffer, Cur, Len)
    end

    const function Map8Des(): { [K]: V }
        const Cur = Cursor
        const Len = buffer.readu8(ReadBuffer :: buffer, Cur)
        const Map = {}
        Cursor = Cur + 1
        for _ = 1, Len do
            Map[KeyDes()] = ValueDes()
        end
        return Map
    end

    Map8Node[SER] = Map8Ser
    Map8Node[DES] = Map8Des

    return Map8Node
end

-- Map24 (24 bits for length write, meaning max amount of elements in the map is 16_777_215)
--- Map with a `u24` entry-count prefix.
--- @within Types
--- @tag Collections
--- @function Map24
--- @param keyNode SerdesNode<K> -- Key schema.
--- @param valueNode SerdesNode<V> -- Value schema.
--- @return SerdesNode<{ [K]: V }>

const function Map24<K, V>(KeyNode: SerdesNode<K>, ValueNode: SerdesNode<V>): SerdesNode<{ [K]: V }>
    const Map24Node: SerdesNode<{ [K]: V }> = {}

    const KeySer = KeyNode[SER] :: Ser<K>
    const KeyDes = KeyNode[DES] :: Des<K>

    const ValueSer = ValueNode[SER] :: Ser<V>
    const ValueDes = ValueNode[DES] :: Des<V>

    const function Map24Ser(Map: { [K]: V })
        const Cur = Cursor
        local Len = 0
        Cursor = Cur + 3
        for Key, Value in Map do
            Len += 1
            KeySer(Key)
            ValueSer(Value)
        end
        const Buf = WriteBuffer
        buffer.writeu16(Buf, Cur, bit32.band(Len, 0xFFFF))
        buffer.writeu8(Buf, Cur + 2, bit32.band(bit32.rshift(Len, 16), 0xFF))
    end

    const function Map24Des(): { [K]: V }
        local Cur = Cursor
        const Buf = ReadBuffer :: buffer
        const b1: number = buffer.readu16(Buf, Cur)
        const b2: number = buffer.readu8(Buf, Cur + 2)
        const Len = bit32.bor(b1, bit32.lshift(b2, 16))
        const Map = {}
        Cursor = Cur + 3
        for _ = 1, Len do
            Map[KeyDes()] = ValueDes()
        end
        return Map
    end

    Map24Node[SER] = Map24Ser
    Map24Node[DES] = Map24Des

    return Map24Node
end

-- ArrayFixed (fixed length)
--- Fixed-length array with no count prefix.
--- @within Types
--- @tag Collections
--- @function ArrayFixed
--- @param node SerdesNode<T> -- Element schema.
--- @param length number -- Exact element count.
--- @return SerdesNode<{ T }>

const function ArrayFixed<T>(Node: SerdesNode<T>, Length: number): SerdesNode<{ T }>
    const ArrayFixedNode: SerdesNode<{ T }> = {}

    const Ser = Node[SER] :: Ser<T>
    const Des = Node[DES] :: Des<T>

    const function ArrayFixedSer(Array: { T })
        for _, Value in Ipairs(Array) do
            Ser(Value)
        end
    end

    const function ArrayFixedDes(): { T }
        const Array = CreateTable<<T>>(Length)
        for i = 1, Length do
            Array[i] = Des()
        end
        return Array
    end

    ArrayFixedNode[SER] = ArrayFixedSer
    ArrayFixedNode[DES] = ArrayFixedDes

    return ArrayFixedNode
end

-- MapFixed (fixed length)
--- Fixed-length map with no count prefix.
--- @within Types
--- @tag Collections
--- @function MapFixed
--- @param keyNode SerdesNode<K> -- Key schema.
--- @param valueNode SerdesNode<V> -- Value schema.
--- @param length number -- Exact entry count.
--- @return SerdesNode<{ [K]: V }>

const function MapFixed<K, V>(KeyNode: SerdesNode<K>, ValueNode: SerdesNode<V>, Length: number): SerdesNode<{ [K]: V }>
    const MapFixedNode: SerdesNode<{ [K]: V }> = {}

    const KeySer = KeyNode[SER] :: Ser<K>
    const KeyDes = KeyNode[DES] :: Des<K>

    const ValueSer = ValueNode[SER] :: Ser<V>
    const ValueDes = ValueNode[DES] :: Des<V>

    const function MapFixedSer(Map: { [K]: V })
        for Key, Value in Map do
            KeySer(Key)
            ValueSer(Value)
        end
    end

    const function MapFixedDes(): { [K]: V }
        const Map = {}
        for _ = 1, Length do
            Map[KeyDes()] = ValueDes()
        end
        return Map
    end

    MapFixedNode[SER] = MapFixedSer
    MapFixedNode[DES] = MapFixedDes

    return MapFixedNode
end

-- IEEE-754 Half Precision Float
--- Half-precision float. 2 bytes. Lossy.
--- @within Types
--- @tag Primitives
--- @prop F16 SerdesNode<number>

const F16: SerdesNode<number> = {}
do
    const function F16Ser(Value: number)
        const Conv = FloatConverter
        buffer.writef32(Conv, 0, Value)
        const Bits: number = buffer.readu32(Conv, 0)

        const Sign: number = bit32.rshift(bit32.band(Bits, 0x80000000), 16)
        const Exp: number = bit32.band(bit32.rshift(Bits, 23), 0xFF)
        const Mant: number = bit32.band(Bits, 0x7FFFFF)

        local Packed: number
        if Exp == 0 then
            Packed = Sign
        elseif Exp >= 143 then
            Packed = bit32.bor(Sign, 0x7C00)
        elseif Exp <= 112 then
            Packed = Sign
        else
            const F16Exp = bit32.lshift(Exp - 112, 10)
            const F16Mant = bit32.rshift(Mant, 13)
            Packed = bit32.bor(Sign, F16Exp, F16Mant)
        end

        const Cur = Cursor
        buffer.writeu16(WriteBuffer, Cur, Packed)
        Cursor = Cur + 2
    end

    const function F16Deser(): number
        const Cur = Cursor
        const Packed: number = buffer.readu16(ReadBuffer :: buffer, Cur)
        Cursor = Cur + 2
    
        const Exp16: number = bit32.band(bit32.rshift(Packed, 10), 0x1F)
        
        if Exp16 == 0 then
            return 0
        end
    
        const Sign: number = bit32.band(Packed, 0x8000)
        const Mant10: number = bit32.band(Packed, 0x3FF)
    
        const Result: number = math.ldexp(1 + Mant10 / 1024, Exp16 - 15)
        
        return if Sign == 0 then Result else -Result
    end

    F16[SER] = F16Ser
    F16[DES] = F16Deser
end

-- Custom precision float
--- 24-bit float. 3 bytes. Lossy.
--- @within Types
--- @tag Primitives
--- @prop F24 SerdesNode<number>

const F24: SerdesNode<number> = {}
do
    const function F24Ser(Value: number)
        const Buf = WriteBuffer
        const Conv = FloatConverter

        buffer.writef32(Conv, 0, Value)
        const Bits: number = buffer.readu32(Conv, 0)
        
        -- drop the bottom 8 bits of precision to shrink it to 24 bits
        const Packed: number = bit32.rshift(Bits, 8)

        local Cur = Cursor
        buffer.writeu16(Buf, Cur, bit32.band(Packed, 0xFFFF))
        Cur += 2
        buffer.writeu8(Buf, Cur, bit32.rshift(Packed, 16))
        
        Cursor = Cur + 1
    end

    const function F24Deser(): number
        local Cur = Cursor
        const Buf = ReadBuffer :: buffer
        const b1: number = buffer.readu16(Buf, Cur)
        Cur += 2
        const b2: number = buffer.readu8(Buf, Cur)
        Cursor = Cur + 1

        const Packed: number = bit32.bor(b1, bit32.lshift(b2, 16))

        const Exp8: number = bit32.band(bit32.rshift(Packed, 15), 0xFF)
        
        if Exp8 == 0 then
            return 0
        end

        const Sign: number = bit32.band(Packed, 0x800000)
        if Exp8 == 255 then
            return if Sign == 0 then MathHuge else NMathHuge
        end

        const Mant15: number = bit32.band(Packed, 0x7FFF)
        const Result: number = math.ldexp(1 + Mant15 / 32768, Exp8 - 127)

        return if Sign == 0 then Result else -Result
    end

    F24[SER] = F24Ser
    F24[DES] = F24Deser
end

-- Unsigned 24-bit Integer
--- Unsigned 24-bit integer. 3 bytes.
--- @within Types
--- @tag Primitives
--- @prop U24 SerdesNode<number>

const U24: SerdesNode<number> = {}
do
    const function U24Ser(Value: number)
        local Cur = Cursor
        const Buf = WriteBuffer
        buffer.writeu16(Buf, Cur, bit32.band(Value, 0xFFFF))
        Cur += 2
        buffer.writeu8(Buf, Cur, bit32.band(bit32.rshift(Value, 16), 0xFF))
        
        Cursor = Cur + 1
    end

    const function U24Deser(): number
        local Cur = Cursor
        const Buf = ReadBuffer :: buffer
        const b1: number = buffer.readu16(Buf, Cur)
        Cur += 2
        const b2: number = buffer.readu8(Buf, Cur)
        Cursor = Cur + 1

        return bit32.bor(b1, bit32.lshift(b2, 16))
    end

    U24[SER] = U24Ser
    U24[DES] = U24Deser
end

-- Signed 24-bit integer
--- Signed 24-bit integer. 3 bytes.
--- @within Types
--- @tag Primitives
--- @prop I24 SerdesNode<number>

const I24: SerdesNode<number> = {}
do
    const function I24Ser(Value: number)
        -- exactly the same as U24
        local Cur = Cursor
        const Buf = WriteBuffer
        buffer.writeu16(Buf, Cur, bit32.band(Value, 0xFFFF))
        Cur += 2
        buffer.writeu8(Buf, Cur, bit32.band(bit32.rshift(Value, 16), 0xFF))
        
        Cursor = Cur + 1
    end

    const function I24Deser(): number
        local Cur = Cursor
        const Buf = ReadBuffer :: buffer
        const b1: number = buffer.readu16(Buf, Cur)
        Cur += 2
        const b2: number = buffer.readu8(Buf, Cur)
        Cursor = Cur + 1

        const Packed: number = bit32.bor(b1, bit32.lshift(b2, 16))
        return if Packed >= 0x800000 then Packed - 0x1000000 else Packed
    end

    I24[SER] = I24Ser
    I24[DES] = I24Deser
end

--- `vector` with three `f24` components. 9 bytes.
--- @within Types
--- @tag Vectors
--- @prop VectorF24 SerdesNode<vector>

const VectorF24: SerdesNode<vector> = {} -- Vector (3x3 bytes, each element is F24)
do
    const function VectorF24Ser(Value: vector)
        local Cur = Cursor
        const Buf = WriteBuffer
        const Conv = FloatConverter

        -- inlined f24 3 times :sob: :pray:
        -- x
        do
            buffer.writef32(Conv, 0, Value.x)
            const Bits: number = buffer.readu32(Conv, 0)
            const Packed: number = bit32.rshift(Bits, 8)
            buffer.writeu16(Buf, Cur, bit32.band(Packed, 0xFFFF))
            buffer.writeu8(Buf, Cur + 2, bit32.rshift(Packed, 16))
        end
        -- y
        do
            buffer.writef32(Conv, 0, Value.y)
            const Bits: number = buffer.readu32(Conv, 0)
            const Packed: number = bit32.rshift(Bits, 8)
            buffer.writeu16(Buf, Cur + 3, bit32.band(Packed, 0xFFFF))
            buffer.writeu8(Buf, Cur + 5, bit32.rshift(Packed, 16))
        end
        -- z
        do
            buffer.writef32(Conv, 0, Value.z)
            const Bits: number = buffer.readu32(Conv, 0)
            const Packed: number = bit32.rshift(Bits, 8)
            buffer.writeu16(Buf, Cur + 6, bit32.band(Packed, 0xFFFF))
            buffer.writeu8(Buf, Cur + 8, bit32.rshift(Packed, 16))
        end

        Cursor = Cur + 9
    end

    const function VectorF24Des(): vector
        local Cur = Cursor
        const Buf = ReadBuffer :: buffer
        -- inlined f24des too, sorry :pray:
        local x = 0
        do
            const b1: number = buffer.readu16(Buf :: buffer, Cur)
            const b2: number = buffer.readu8(Buf :: buffer, Cur + 2)

            const Packed: number = bit32.bor(b1, bit32.lshift(b2, 16))

            const Exp8: number = bit32.band(bit32.rshift(Packed, 15), 0xFF)
            
            if Exp8 ~= 0 then
                const Sign: number = bit32.band(Packed, 0x800000)
                if Exp8 == 255 then
                    x = if Sign == 0 then MathHuge else NMathHuge
                else
                    const Mant15: number = bit32.band(Packed, 0x7FFF)
                    const Result: number = math.ldexp(1 + Mant15 / 32768, Exp8 - 127)
        
                    x = if Sign == 0 then Result else -Result
                end
            end
        end

        local y = 0
        do
            const b1: number = buffer.readu16(Buf :: buffer, Cur + 3)
            const b2: number = buffer.readu8(Buf :: buffer, Cur + 5)

            const Packed: number = bit32.bor(b1, bit32.lshift(b2, 16))

            const Exp8: number = bit32.band(bit32.rshift(Packed, 15), 0xFF)
            
            if Exp8 ~= 0 then
                const Sign: number = bit32.band(Packed, 0x800000)
                if Exp8 == 255 then
                    y = if Sign == 0 then MathHuge else NMathHuge
                else
                    const Mant15: number = bit32.band(Packed, 0x7FFF)
                    const Result: number = math.ldexp(1 + Mant15 / 32768, Exp8 - 127)
        
                    y = if Sign == 0 then Result else -Result
                end
            end
        end

        local z = 0
        do
            const b1: number = buffer.readu16(Buf, Cur + 6)
            const b2: number = buffer.readu8(Buf, Cur + 8)

            const Packed: number = bit32.bor(b1, bit32.lshift(b2, 16))

            const Exp8: number = bit32.band(bit32.rshift(Packed, 15), 0xFF)
            
            if Exp8 ~= 0 then
                const Sign: number = bit32.band(Packed, 0x800000)
                if Exp8 == 255 then
                    z = if Sign == 0 then MathHuge else NMathHuge
                else
                    const Mant15: number = bit32.band(Packed, 0x7FFF)
                    const Result: number = math.ldexp(1 + Mant15 / 32768, Exp8 - 127)
        
                    z = if Sign == 0 then Result else -Result
                end
            end
        end

        Cursor = Cur + 9
        return vector.create(x, y, z)
    end

    VectorF24[SER] = VectorF24Ser
    VectorF24[DES] = VectorF24Des
end

--- `vector` with three `f16` components. 6 bytes.
--- @within Types
--- @tag Vectors
--- @prop VectorF16 SerdesNode<vector>

const VectorF16: SerdesNode<vector> = {} -- Vector (3x2 bytes, each element is F16)
do
    const function VectorF16Ser(Value: vector)
        local Cur = Cursor
        const Buf = WriteBuffer
        const Conv = FloatConverter

        -- x
        do
            buffer.writef32(Conv, 0, Value.x)
            const Bits: number = buffer.readu32(Conv, 0)

            const Sign: number = bit32.rshift(bit32.band(Bits, 0x80000000), 16)
            const Exp: number = bit32.band(bit32.rshift(Bits, 23), 0xFF)
            const Mant: number = bit32.band(Bits, 0x7FFFFF)

            local Packed: number
            if Exp == 0 then
                Packed = Sign
            elseif Exp >= 143 then
                Packed = bit32.bor(Sign, 0x7C00)
            elseif Exp <= 112 then
                Packed = Sign
            else
                const F16Exp = bit32.lshift(Exp - 112, 10)
                const F16Mant = bit32.rshift(Mant, 13)
                Packed = bit32.bor(Sign, F16Exp, F16Mant)
            end

            buffer.writeu16(Buf, Cur, Packed)
        end
        -- y
        do
            buffer.writef32(Conv, 0, Value.y)
            const Bits: number = buffer.readu32(Conv, 0)

            const Sign: number = bit32.rshift(bit32.band(Bits, 0x80000000), 16)
            const Exp: number = bit32.band(bit32.rshift(Bits, 23), 0xFF)
            const Mant: number = bit32.band(Bits, 0x7FFFFF)

            local Packed: number
            if Exp == 0 then
                Packed = Sign
            elseif Exp >= 143 then
                Packed = bit32.bor(Sign, 0x7C00)
            elseif Exp <= 112 then
                Packed = Sign
            else
                const F16Exp = bit32.lshift(Exp - 112, 10)
                const F16Mant = bit32.rshift(Mant, 13)
                Packed = bit32.bor(Sign, F16Exp, F16Mant)
            end

            buffer.writeu16(Buf, Cur + 2, Packed)
        end
        -- z
        do
            buffer.writef32(Conv, 0, Value.z)
            const Bits: number = buffer.readu32(Conv, 0)

            const Sign: number = bit32.rshift(bit32.band(Bits, 0x80000000), 16)
            const Exp: number = bit32.band(bit32.rshift(Bits, 23), 0xFF)
            const Mant: number = bit32.band(Bits, 0x7FFFFF)

            local Packed: number
            if Exp == 0 then
                Packed = Sign
            elseif Exp >= 143 then
                Packed = bit32.bor(Sign, 0x7C00)
            elseif Exp <= 112 then
                Packed = Sign
            else
                const F16Exp = bit32.lshift(Exp - 112, 10)
                const F16Mant = bit32.rshift(Mant, 13)
                Packed = bit32.bor(Sign, F16Exp, F16Mant)
            end

            buffer.writeu16(Buf, Cur + 4, Packed)
        end

        Cursor = Cur + 6
    end

    const function VectorF16Des(): vector
        local Cur = Cursor
        const Buf = ReadBuffer :: buffer

        local x = 0
        do
            const Packed: number = buffer.readu16(Buf, Cur)

            const Exp16: number = bit32.band(bit32.rshift(Packed, 10), 0x1F)

            if Exp16 ~= 0 then
                const Sign: number = bit32.band(Packed, 0x8000)
                const Mant10: number = bit32.band(Packed, 0x3FF)
                const Result: number = math.ldexp(1 + Mant10 / 1024, Exp16 - 15)

                x = if Sign == 0 then Result else -Result
            end
        end

        local y = 0
        do
            const Packed: number = buffer.readu16(Buf, Cur + 2)

            const Exp16: number = bit32.band(bit32.rshift(Packed, 10), 0x1F)

            if Exp16 ~= 0 then
                const Sign: number = bit32.band(Packed, 0x8000)
                const Mant10: number = bit32.band(Packed, 0x3FF)
                const Result: number = math.ldexp(1 + Mant10 / 1024, Exp16 - 15)

                y = if Sign == 0 then Result else -Result
            end
        end

        local z = 0
        do
            const Packed: number = buffer.readu16(Buf, Cur + 4)

            const Exp16: number = bit32.band(bit32.rshift(Packed, 10), 0x1F)

            if Exp16 ~= 0 then
                const Sign: number = bit32.band(Packed, 0x8000)
                const Mant10: number = bit32.band(Packed, 0x3FF)
                const Result: number = math.ldexp(1 + Mant10 / 1024, Exp16 - 15)

                z = if Sign == 0 then Result else -Result
            end
        end

        Cursor = Cur + 6
        return vector.create(x, y, z)
    end

    VectorF16[SER] = VectorF16Ser
    VectorF16[DES] = VectorF16Des
end

--- `vector` with three `u16` components. 6 bytes.
--- @within Types
--- @tag Vectors
--- @prop VectorU16 SerdesNode<vector>

const VectorU16: SerdesNode<vector> = {} -- Vector (3x2 bytes, each element is U16)
do
    const function VectorU16Ser(Value: vector)
        local Cur = Cursor
        const Buf = WriteBuffer

        buffer.writeu16(Buf, Cur, Value.x)
        buffer.writeu16(Buf, Cur + 2, Value.y)
        buffer.writeu16(Buf, Cur + 4, Value.z)
        Cursor = Cur + 6
    end

    const function VectorU16Des(): vector
        local Cur = Cursor
        const Buf = ReadBuffer :: buffer

        const x = buffer.readu16(Buf, Cur)
        const y = buffer.readu16(Buf, Cur + 2)
        const z = buffer.readu16(Buf, Cur + 4)
        Cursor = Cur + 6

        return vector.create(x, y, z)
    end

    VectorU16[SER] = VectorU16Ser
    VectorU16[DES] = VectorU16Des
end

--- `vector` with three `i16` components. 6 bytes.
--- @within Types
--- @tag Vectors
--- @prop VectorI16 SerdesNode<vector>

const VectorI16: SerdesNode<vector> = {} -- Vector (3x2 bytes, each element is I16)
do
    const function VectorI16Ser(Value: vector)
        local Cur = Cursor
        const Buf = WriteBuffer

        buffer.writei16(Buf, Cur, Value.x)
        buffer.writei16(Buf, Cur + 2, Value.y)
        buffer.writei16(Buf, Cur + 4, Value.z)
        Cursor = Cur + 6
    end

    const function VectorI16Des(): vector
        local Cur = Cursor
        const Buf = ReadBuffer :: buffer

        const x = buffer.readi16(Buf, Cur)
        const y = buffer.readi16(Buf, Cur + 2)
        const z = buffer.readi16(Buf, Cur + 4)
        Cursor = Cur + 6

        return vector.create(x, y, z)
    end

    VectorI16[SER] = VectorI16Ser
    VectorI16[DES] = VectorI16Des
end

--- `vector` with three `u8` components. 3 bytes.
--- @within Types
--- @tag Vectors
--- @prop VectorU8 SerdesNode<vector>

const VectorU8: SerdesNode<vector> = {} -- Vector (3x1 bytes, each element is U8)
do
    const function VectorU8Ser(Value: vector)
        local Cur = Cursor
        const Buf = WriteBuffer

        buffer.writeu8(Buf, Cur, Value.x)
        buffer.writeu8(Buf, Cur + 1, Value.y)
        buffer.writeu8(Buf, Cur + 2, Value.z)
        Cursor = Cur + 3
    end

    const function VectorU8Des(): vector
        local Cur = Cursor
        const Buf = ReadBuffer :: buffer

        const x = buffer.readu8(Buf, Cur)
        const y = buffer.readu8(Buf, Cur + 1)
        const z = buffer.readu8(Buf, Cur + 2)
        Cursor = Cur + 3

        return vector.create(x, y, z)
    end

    VectorU8[SER] = VectorU8Ser
    VectorU8[DES] = VectorU8Des
end

--- `vector` with three `i8` components. 3 bytes.
--- @within Types
--- @tag Vectors
--- @prop VectorI8 SerdesNode<vector>

const VectorI8: SerdesNode<vector> = {} -- Vector (3x1 bytes, each element is I8)
do
    const function VectorI8Ser(Value: vector)
        local Cur = Cursor
        const Buf = WriteBuffer

        buffer.writei8(Buf, Cur, Value.x)
        buffer.writei8(Buf, Cur + 1, Value.y)
        buffer.writei8(Buf, Cur + 2, Value.z)
        Cursor = Cur + 3
    end

    const function VectorI8Des(): vector
        local Cur = Cursor
        const Buf = ReadBuffer :: buffer

        const x = buffer.readi8(Buf, Cur)
        const y = buffer.readi8(Buf, Cur + 1)
        const z = buffer.readi8(Buf, Cur + 2)
        Cursor = Cur + 3

        return vector.create(x, y, z)
    end

    VectorI8[SER] = VectorI8Ser
    VectorI8[DES] = VectorI8Des
end

--- `vector` with three `u24` components. 9 bytes.
--- @within Types
--- @tag Vectors
--- @prop VectorU24 SerdesNode<vector>

const VectorU24: SerdesNode<vector> = {} -- Vector (3x3 bytes, each element is U24)
do
    const function VectorU24Ser(Value: vector)
        local Cur = Cursor
        const Buf = WriteBuffer

        -- x
        do
            const x = Value.x
            buffer.writeu16(Buf, Cur, bit32.band(x, 0xFFFF))
            buffer.writeu8(Buf, Cur + 2, bit32.band(bit32.rshift(x, 16), 0xFF))
        end
        -- y
        do
            const y = Value.y
            buffer.writeu16(Buf, Cur + 3, bit32.band(y, 0xFFFF))
            buffer.writeu8(Buf, Cur + 5, bit32.band(bit32.rshift(y, 16), 0xFF))
        end
        -- z
        do
            const z = Value.z
            buffer.writeu16(Buf, Cur + 6, bit32.band(z, 0xFFFF))
            buffer.writeu8(Buf, Cur + 8, bit32.band(bit32.rshift(z, 16), 0xFF))
        end

        Cursor = Cur + 9
    end

    const function VectorU24Des(): vector
        local Cur = Cursor
        const Buf = ReadBuffer :: buffer

        local x = 0
        do
            const b1: number = buffer.readu16(Buf :: buffer, Cur)
            const b2: number = buffer.readu8(Buf :: buffer, Cur + 2)

            x = bit32.bor(b1, bit32.lshift(b2, 16))
        end

        local y = 0
        do
            const b1: number = buffer.readu16(Buf :: buffer, Cur + 3)
            const b2: number = buffer.readu8(Buf :: buffer, Cur + 5)

            y = bit32.bor(b1, bit32.lshift(b2, 16))
        end

        local z = 0
        do
            const b1: number = buffer.readu16(Buf :: buffer, Cur + 6)
            const b2: number = buffer.readu8(Buf :: buffer, Cur + 8)

            z = bit32.bor(b1, bit32.lshift(b2, 16))
        end

        Cursor = Cur + 9
        return vector.create(x, y, z)
    end

    VectorU24[SER] = VectorU24Ser
    VectorU24[DES] = VectorU24Des
end

--- `vector` with three `i24` components. 9 bytes.
--- @within Types
--- @tag Vectors
--- @prop VectorI24 SerdesNode<vector>

const VectorI24: SerdesNode<vector> = {} -- Vector (3x3 bytes, each element is I24)
do
    const function VectorI24Ser(Value: vector)
        local Cur = Cursor
        const Buf = WriteBuffer

        -- x
        do
            const x = Value.x
            buffer.writeu16(Buf, Cur, bit32.band(x, 0xFFFF))
            buffer.writeu8(Buf, Cur + 2, bit32.band(bit32.rshift(x, 16), 0xFF))
        end
        -- y
        do
            const y = Value.y
            buffer.writeu16(Buf, Cur + 3, bit32.band(y, 0xFFFF))
            buffer.writeu8(Buf, Cur + 5, bit32.band(bit32.rshift(y, 16), 0xFF))
        end
        -- z
        do
            const z = Value.z
            buffer.writeu16(Buf, Cur + 6, bit32.band(z, 0xFFFF))
            buffer.writeu8(Buf, Cur + 8, bit32.band(bit32.rshift(z, 16), 0xFF))
        end

        Cursor = Cur + 9
    end

    const function VectorI24Des(): vector
        local Cur = Cursor
        const Buf = ReadBuffer :: buffer

        local x = 0
        do
            const b1: number = buffer.readu16(Buf :: buffer, Cur)
            const b2: number = buffer.readu8(Buf :: buffer, Cur + 2)

            const Packed: number = bit32.bor(b1, bit32.lshift(b2, 16))
            x = if Packed >= 0x800000 then Packed - 0x1000000 else Packed
        end

        local y = 0
        do
            const b1: number = buffer.readu16(Buf :: buffer, Cur + 3)
            const b2: number = buffer.readu8(Buf :: buffer, Cur + 5)

            const Packed: number = bit32.bor(b1, bit32.lshift(b2, 16))
            y = if Packed >= 0x800000 then Packed - 0x1000000 else Packed
        end

        local z = 0
        do
            const b1: number = buffer.readu16(Buf :: buffer, Cur + 6)
            const b2: number = buffer.readu8(Buf :: buffer, Cur + 8)

            const Packed: number = bit32.bor(b1, bit32.lshift(b2, 16))
            z = if Packed >= 0x800000 then Packed - 0x1000000 else Packed
        end

        Cursor = Cur + 9
        return vector.create(x, y, z)
    end

    VectorI24[SER] = VectorI24Ser
    VectorI24[DES] = VectorI24Des
end

--- Boolean stored as one byte (`0` or `1`).
--- @within Types
--- @tag Primitives
--- @prop Bool SerdesNode<boolean>

const Bool: SerdesNode<boolean> = {}
do
    const function BoolSer(Value: boolean)
        const Cur = Cursor
        buffer.writeu8(WriteBuffer, Cur, Value and 1 or 0)
        Cursor = Cur + 1
    end

    const function BoolDes(): boolean
        const Cur = Cursor
        const Value = buffer.readu8(ReadBuffer :: buffer, Cur)
        Cursor = Cur + 1
        return Value == 1
    end

    Bool[SER] = BoolSer
    Bool[DES] = BoolDes
end

--- Eight booleans packed into 1 byte.
--- @within Types
--- @tag Special
--- @prop BoolPacked SerdesNode<{ boolean }>

const BoolPacked: SerdesNode<{ boolean }> = {}
do
    const function BoolPackedSer(Value: { boolean })
        local Write = 0
        if Value[1] then
			Write += 1
		end
		if Value[2] then
			Write += 2
		end
		if Value[3] then
			Write += 4
		end
		if Value[4] then
			Write += 8
		end
		if Value[5] then
			Write += 16
		end
		if Value[6] then
			Write += 32
		end
		if Value[7] then
			Write += 64
		end
		if Value[8] then
			Write += 128
		end

        const Cur = Cursor
        buffer.writeu8(WriteBuffer, Cur, Write)
        Cursor = Cur + 1
    end

    const function BoolPackedDes(): { boolean }
        const Cur = Cursor
        const Byte = buffer.readu8(ReadBuffer :: buffer, Cur)
        Cursor = Cur + 1

        return { 
			bit32.btest(Byte, 1),
			bit32.btest(Byte, 2),
			bit32.btest(Byte, 4),
			bit32.btest(Byte, 8),
			bit32.btest(Byte, 16),
			bit32.btest(Byte, 32),
			bit32.btest(Byte, 64),
			bit32.btest(Byte, 128),
		}
    end

    BoolPacked[SER] = BoolPackedSer
    BoolPacked[DES] = BoolPackedDes
end

-- Buffer (2 bytes for length, meaning max amount of bytes in the buffer is 65535)
--- Buffer with a `u16` byte-length prefix.
--- @within Types
--- @tag Special
--- @prop Buffer SerdesNode<buffer>

const Buffer: SerdesNode<buffer> = {}
do
    const function BufferSer(Value: buffer)
        local Cur = Cursor
        const Len = buffer.len(Value)
        const Buf = WriteBuffer
        buffer.writeu16(Buf, Cur, Len)
        Cur += 2
        buffer.copy(Buf, Cur, Value, 0, Len)
        Cursor = Cur + Len
    end

    const function BufferDes(): buffer
        local Cur = Cursor
        const ReadBuf = ReadBuffer :: buffer
        const Length = buffer.readu16(ReadBuf, Cur)
        Cur += 2
        const Buf = buffer.create(Length)
        buffer.copy(Buf, 0, ReadBuf, Cur, Length)
        Cursor = Cur + Length
        return Buf
    end

    Buffer[SER] = BufferSer
    Buffer[DES] = BufferDes
end

-- Buffer8 (1 byte for length, meaning max amount of bytes in the buffer is 255)
--- Buffer with a `u8` byte-length prefix.
--- @within Types
--- @tag Special
--- @prop Buffer8 SerdesNode<buffer>

const Buffer8: SerdesNode<buffer> = {}
do
    const function Buffer8Ser(Value: buffer)
        local Cur = Cursor
        const Len = buffer.len(Value)
        const Buf = WriteBuffer
        buffer.writeu8(Buf, Cur, Len)
        Cur += 1
        buffer.copy(Buf, Cur, Value, 0, Len)
        Cursor = Cur + Len
    end

    const function Buffer8Des(): buffer
        local Cur = Cursor
        const ReadBuf = ReadBuffer :: buffer
        const Length = buffer.readu8(ReadBuf, Cur)
        Cur += 1
        const Buf = buffer.create(Length)
        buffer.copy(Buf, 0, ReadBuf, Cur, Length)
        Cursor = Cur + Length
        return Buf
    end

    Buffer8[SER] = Buffer8Ser
    Buffer8[DES] = Buffer8Des
end

-- Buffer24 (3 bytes for length, meaning max amount of bytes in the buffer is 16_777_215)
--- Buffer with a `u24` byte-length prefix.
--- @within Types
--- @tag Special
--- @prop Buffer24 SerdesNode<buffer>

const Buffer24: SerdesNode<buffer> = {}
do
    const function Buffer24Ser(Value: buffer)
        local Cur = Cursor
        const Len = buffer.len(Value)
        const Buf = WriteBuffer
        buffer.writeu16(Buf, Cur, bit32.band(Len, 0xFFFF))
        buffer.writeu8(Buf, Cur + 2, bit32.band(bit32.rshift(Len, 16), 0xFF))
        buffer.copy(Buf, Cur + 3, Value, 0, Len)
        Cursor = Cur + 3 + Len
    end

    const function Buffer24Des(): buffer
        local Cur = Cursor
        const Buf = ReadBuffer :: buffer
        const b1: number = buffer.readu16(Buf, Cur)
        const b2: number = buffer.readu8(Buf, Cur + 2)

        const Length = bit32.bor(b1, bit32.lshift(b2, 16))
        const b = buffer.create(Length)
        buffer.copy(b, 0, Buf, Cur + 3, Length)
        Cursor = Cur + 3 + Length
        return b
    end

    Buffer24[SER] = Buffer24Ser
    Buffer24[DES] = Buffer24Des
end

-- BufferFixed (fixed length)
--- Fixed-length buffer with no length prefix.
--- @within Types
--- @tag Special
--- @function BufferFixed
--- @param length number -- Exact byte length on the wire.
--- @return SerdesNode<buffer>

const function BufferFixed(Length: number): SerdesNode<buffer>
    const BufferFixedNode: SerdesNode<buffer> = {}

    const function BufferFixedSer(Value: buffer)
        local Cur = Cursor
        const Buf = WriteBuffer
        buffer.copy(Buf, Cur, Value, 0, Length)
        Cursor = Cur + Length
    end

    const function BufferFixedDes(): buffer
        local Cur = Cursor
        const Buf = ReadBuffer :: buffer
        const Value = buffer.create(Length)
        buffer.copy(Value, 0, Buf, Cur, Length)
        Cursor = Cur + Length
        return Value
    end

    BufferFixedNode[SER] = BufferFixedSer
    BufferFixedNode[DES] = BufferFixedDes

    return BufferFixedNode
end

--- Optional value prefixed by a one-byte presence flag.
--- @within Types
--- @tag Collections
--- @function Optional
--- @param node SerdesNode<T> -- Inner schema.
--- @return SerdesNode<T?>

const function Optional<T>(Node: SerdesNode<T>): SerdesNode<T?>
    const OptionalNode: SerdesNode<T?> = {}

    const function OptionalSer(Value: T?)
        const Cur = Cursor
        const Exists = Value ~= nil
        buffer.writeu8(WriteBuffer, Cur, Exists and 1 or 0)
        Cursor = Cur + 1
        if Exists then
            const Ser = Node[SER] :: Ser<T>
            Ser(Value)
        end
    end

    const function OptionalDes(): T?
        const Cur = Cursor
        const Exists = buffer.readu8(ReadBuffer :: buffer, Cur)
        Cursor = Cur + 1
        if Exists == 1 then
            const Des = Node[DES] :: Des<T>
            return Des()
        end

        return nil
    end

    OptionalNode[SER] = OptionalSer
    OptionalNode[DES] = OptionalDes

    return OptionalNode
end

Types.U8 = U8
Types.I8 = I8
Types.U16 = U16
Types.I16 = I16
Types.U32 = U32
Types.I32 = I32
Types.F32 = F32
Types.F64 = F64
Types.String = String
Types.String8 = String8
Types.Array = Array
Types.Array8 = Array8
Types.Array24 = Array24
Types.Struct = Struct
Types.Vector = Vector
Types.Map = Map
Types.Map8 = Map8
Types.Map24 = Map24
Types.ArrayFixed = ArrayFixed
Types.F16 = F16
Types.F24 = F24
Types.MapFixed = MapFixed
Types.U24 = U24
Types.I24 = I24
Types.VectorF24 = VectorF24
Types.VectorF16 = VectorF16
Types.VectorU16 = VectorU16
Types.VectorI16 = VectorI16
Types.VectorU8 = VectorU8
Types.VectorI8 = VectorI8
Types.VectorU24 = VectorU24
Types.VectorI24 = VectorI24
Types.Bool = Bool
Types.BoolPacked = BoolPacked
Types.StringFixed = StringFixed
Types.Buffer = Buffer
Types.Buffer8 = Buffer8
Types.Buffer24 = Buffer24
Types.BufferFixed = BufferFixed
Types.Optional = Optional

---------------------------------------------------------
-- API
---------------------------------------------------------

--- Serializes a value according to a schema and returns an exactly sized buffer.
---
--- Values are not validated. The caller must provide data that matches the
--- schema and the selected node's range.
--- @tag Core
--- @param Schema SerdesNode<T> -- Schema that defines the wire representation.
--- @param Value T -- Value to serialize.
--- @return buffer
function VoidSentryUltimate.Serialize<T>(Schema: SerdesNode<T>, Value: T): buffer
	Cursor = 0
	const Ser = Schema[SER] :: Ser<T>
	Ser(Value)
    const Cur = Cursor
	const Buf = buffer.create(Cur)
	buffer.copy(Buf, 0, WriteBuffer, 0, Cur)
	return Buf
end

--- Serializes a value into a new buffer after a zero-filled prefix.
---
--- The returned buffer has `Offset` bytes before the payload. Use this when a
--- caller will fill a packet header separately.
--- @tag Core
--- @param Schema SerdesNode<T> -- Schema that defines the wire representation.
--- @param Value T -- Value to serialize.
--- @param Offset number -- Number of bytes reserved before the payload.
--- @return buffer
function VoidSentryUltimate.SerializeWithOffset<T>(Schema: SerdesNode<T>, Value: T, Offset: number): buffer
	Cursor = 0
	const Ser = Schema[SER] :: Ser<T>
	Ser(Value)
    const Cur = Cursor
	const Buf = buffer.create(Cur + Offset)
	buffer.copy(Buf, Offset, WriteBuffer, 0, Cur)
	return Buf
end

--- Deserializes a buffer from byte zero using the supplied schema.
---
--- The schema must match the schema and node choices used by the writer.
--- @tag Core
--- @param Schema SerdesNode<T> -- Schema that defines the wire representation.
--- @param Buffer buffer -- Buffer containing the encoded value.
--- @return T
function VoidSentryUltimate.Deserialize<T>(Schema: SerdesNode<T>, Buffer: buffer): T
    Cursor = 0
	ReadBuffer = Buffer
	const Des = Schema[DES] :: Des<T>
	const Value = Des()
	ReadBuffer = nil -- gc the buffer if no more references exist
	return Value
end

--- Writes a serialized value directly into an existing buffer.
---
--- The destination must already be large enough. `Offset` defaults to zero,
--- and this function does not return the final cursor position.
--- @tag Core
--- @param Schema SerdesNode<T> -- Schema that defines the wire representation.
--- @param Value T -- Value to serialize.
--- @param Buffer buffer -- Existing destination buffer.
--- @param Offset number? -- Byte offset at which writing begins. Defaults to 0.
function VoidSentryUltimate.Push<T>(Schema: SerdesNode<T>, Value: T, Buffer: buffer, Offset: number?): ()
    Offset = Offset or 0
    const BigBufSave = WriteBuffer
    WriteBuffer = Buffer
    Cursor = Offset
    const Ser = Schema[SER] :: Ser<T>
    Ser(Value)
    WriteBuffer = BigBufSave
end

--- Deserializes a value beginning at a byte offset in a buffer.
--- @tag Core
--- @param Schema SerdesNode<T> -- Schema that defines the wire representation.
--- @param Buffer buffer -- Buffer containing the encoded value.
--- @param Offset number -- Byte offset at which reading begins.
--- @return T
function VoidSentryUltimate.DeserializeWithOffset<T>(Schema: SerdesNode<T>, Buffer: buffer, Offset: number): T
    Cursor = Offset
	ReadBuffer = Buffer
	const Des = Schema[DES] :: Des<T>
	const Value = Des()
	ReadBuffer = nil
	return Value
end

--- Replaces the reusable serialization scratch buffer with a new capacity.
---
--- The default capacity is 1,000,000 bytes. Set a different size before
--- serialization when yourw payload limit differs.
--- @tag Core
--- @param NewSize number -- New scratch-buffer size in bytes.
function VoidSentryUltimate.SetWriteBufferSize(NewSize: number): ()
    WriteBuffer = buffer.create(NewSize)
end

return VoidSentryUltimate

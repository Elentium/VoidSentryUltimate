--!native
--!optimize 2
--[[
    VoidSentryUltimate 
    [ V1.0.1 ]
    [ by IAMNOTULTRA3 a.k.a Elentium, Elite ]
    [ Apache-2.0 License ]

    Efficient SerDes library

    Wally: "elentium/voidsentryultimate@1.0.1"
    Pesde: pesde add elentium/voidsentryultimate
    Npm: npm install @elentium/voidsentryultimate
    Docs: https://Elentium.github.io/VoidSentryUltimate
]]

--- Schema-based, validation-free serialization for Roblox.
---
--- Build a `SerdesNode` from `VoidSentryUltimate.Types`, then use the same
--- schema to serialize and deserialize a value. The module includes Roblox
--- nodes for `Vector3`, `Vector2`, `UDim2`, `Instance`, `CFrame`, `Color3`,
--- and `Enum` values. See the Types guide for the complete catalog and wire sizes.
---
--- @class VoidSentryUltimate
---------------------------------------------------------
-- CONSTANTS
---------------------------------------------------------
const SER = 1 -- index of Ser function
const DES = 2 -- index of Des function
const BIG_BUFFER_SIZE = 1_000_000 -- size of big scratch buffer (this also means the max serialize bytes)
const INSTANCE_ATTRIBUTE_NAME = "_VSID" -- attribute that is assigned to each instance and stores unique id
const INSTANCE_SERIALIZATION_ENABLED = true -- if true, assigns attribute `INSTANCE_ATTRIBUTE_NAME` to every instance and fills the map, if false, skips this work

---------------------------------------------------------
-- SERVICES
---------------------------------------------------------
const RunService = game:GetService("RunService")

---------------------------------------------------------
-- MODULE
---------------------------------------------------------
const VoidSentryUltimate = {}
--- Schema type nodes from `VoidSentryUltimate.Types`.
--- @class Types
const Types = {}
VoidSentryUltimate.Types = Types

---------------------------------------------------------
-- TYPES
---------------------------------------------------------
export type Instances = {
    -- Add more instances for autocomplete (optionally)
    Part: Part,
    BasePart: BasePart,
    MeshPart: MeshPart,
    Texture: Texture,
    Model: Model,
    SpawnLocation: SpawnLocation,
}

type function GetInstanceType(ClassName: type, Instances: type, InstanceType: type)
    const Inst = Instances:readproperty(ClassName)

    return Inst or InstanceType
end

type function Optional(Type: type)
    if Type.tag ~= "table" then
        error(`Argument #1 must be a table, got {Type.tag}`)
    end

    const Tbl = types.newtable()
    for Key, Value in Type:properties() do
        const Val = Value.read or Value.write :: type
        Tbl:setproperty(Key, types.optional(Val))
    end
    Tbl:setindexer(types.string, types.any)

    return Tbl
end

type function GetEnumItem(Enum: type)
    if Enum.tag ~= "extern" then
		error(`Expected input tag to be extern, but got {Enum.tag}`, 0)
	end
	
	for _, Value in Enum:properties() do
		const Type = Value.read or Value.write :: type
		if Type.tag == "extern" then
			return Type
		end
	end

	error("Provided input type does not contain extern properties")
end

export type Ser<T> = (T) -> ()
export type Des<T> = () -> T

export type SerdesNode<T> = {
	-- [1] = Ser
	-- [2] = Des
	[number]: Ser<T> | Des<T>,
	_T: T | any,
}

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

type function GetTypeFromTypeNode(Node: type)
    const T = Node:readproperty(types.singleton("_T"))
    if not T then
        error("_T field not found in Node")
    end

    return GetProperTypeFromUnion(T)
end

export type function GetTypeFromTypeNodes(Struct: type)
    if Struct.tag ~= "table" then
        error(`Argument #1 must be a table, got {Struct.tag}`)
    end

    const Tbl = types.newtable()
    for Key, Value in Struct:properties() do
        const Node = Value.read or Value.write :: type

        Tbl:setproperty(Key, GetTypeFromTypeNode(Node))
    end
    Tbl:setindexer(types.string, types.any)

    return Tbl
end

export type Lib = {
    -- TODO: when luau bug is fixed, replace this with read Serialize: <T>(Node: SerdesNode<any> & T, Data: GetTypeFromTypeNode<T>) -> buffer,
    read Serialize: <T>(Node: SerdesNode<T>, Data: T) -> buffer,
    -- when fixed: read SerializeWithOffset: <T>(Node: SerdesNode<any> & T, Data: GetTypeFromTypeNode<T>, Offset: number) -> buffer,
    read SerializeWithOffset: <T>(Node: SerdesNode<T>, Data: T, Offset: number) -> buffer,
    read Deserialize: <T>(Node: SerdesNode<T>, Buffer: buffer) -> GetProperTypeFromUnion<T>,
    read DeserializeWithOffset: <T>(Node: SerdesNode<T>, Buffer: buffer, Offset: number) -> GetProperTypeFromUnion<T>,
    -- when fixed: read Push: <T>(Node: SerdesNode<any> & T, Data: GetTypeFromTypeNode<T>, Buffer: buffer, Offset: number?) -> (),
    read Push: <T>(Node: SerdesNode<T>, Data: T, Buffer: buffer, Offset: number?) -> (),
    read SetWriteBufferSize: (NewSize: number) -> (),

    read Types: {
        read U8: SerdesNode<number>,
        read I8: SerdesNode<number>,
        read U16: SerdesNode<number>,
        read I16: SerdesNode<number>,
        read U32: SerdesNode<number>,
        read I32: SerdesNode<number>,
        read U24: SerdesNode<number>,
        read I24: SerdesNode<number>,
        read F16: SerdesNode<number>,
        read F24: SerdesNode<number>,
        read F32: SerdesNode<number>,
        read F64: SerdesNode<number>,
        read Bool: SerdesNode<boolean>,
        read BoolPacked: SerdesNode<{ boolean }>,
        read String: SerdesNode<string>,
        read String8: SerdesNode<string>,
        read StringFixed: (Length: number) -> SerdesNode<string>,
        read Buffer: SerdesNode<buffer>,
        read Buffer8: SerdesNode<buffer>,
        read Buffer24: SerdesNode<buffer>,
        read BufferFixed: (Length: number) -> SerdesNode<buffer>,
        read Vector: SerdesNode<Vector3>,
        read VectorF16: SerdesNode<Vector3>,
        read VectorF24: SerdesNode<Vector3>,
        read VectorU8: SerdesNode<Vector3>,
        read VectorI8: SerdesNode<Vector3>,
        read VectorU16: SerdesNode<Vector3>,
        read VectorI16: SerdesNode<Vector3>,
        read VectorU24: SerdesNode<Vector3>,
        read VectorI24: SerdesNode<Vector3>,
        read Vector2: SerdesNode<Vector2>,
        read Vector2F16: SerdesNode<Vector2>,
        read Vector2F24: SerdesNode<Vector2>,
        read Vector2U8: SerdesNode<Vector2>,
        read Vector2I8: SerdesNode<Vector2>,
        read Vector2U16: SerdesNode<Vector2>,
        read Vector2I16: SerdesNode<Vector2>,
        read Vector2U24: SerdesNode<Vector2>,
        read Vector2I24: SerdesNode<Vector2>,
        read UDim2: SerdesNode<UDim2>,
        read UDim2Scale: SerdesNode<UDim2>,
        read UDim2Offset: SerdesNode<UDim2>,
        read UDim2OffsetI16: SerdesNode<UDim2>,
        read UDim2ScaleF24: SerdesNode<UDim2>,
        read Array: <T>(Node: SerdesNode<T>) -> SerdesNode<{ T }>,
        read Array8: <T>(Node: SerdesNode<T>) -> SerdesNode<{ T }>,
        read Array24: <T>(Node: SerdesNode<T>) -> SerdesNode<{ T }>,
        read ArrayFixed: <T>(Node: SerdesNode<T>, Length: number) -> SerdesNode<{ T }>,
        read Struct: <T>(Tbl: T & { [string]: SerdesNode<any> }) -> SerdesNode<GetTypeFromTypeNodes<T>>,
        read DeltaStruct: <T>(Tbl: T & { [string]: SerdesNode<any> }) -> SerdesNode<Optional<GetTypeFromTypeNodes<T>>>,
        read DeltaStruct16: <T>(Tbl: T & { [string]: SerdesNode<any> }) -> SerdesNode<Optional<GetTypeFromTypeNodes<T>>>,
        read Map: <K, V>(KeyNode: SerdesNode<K>, ValueNode: SerdesNode<V>) -> SerdesNode<{ [K]: V }>,
        read Map8: <K, V>(KeyNode: SerdesNode<K>, ValueNode: SerdesNode<V>) -> SerdesNode<{ [K]: V }>,
        read Map24: <K, V>(KeyNode: SerdesNode<K>, ValueNode: SerdesNode<V>) -> SerdesNode<{ [K]: V }>,
        read MapFixed: <K, V>(KeyNode: SerdesNode<K>, ValueNode: SerdesNode<V>, Length: number) -> SerdesNode<{ [K]: V }>,
        read Optional: <T>(Node: SerdesNode<T>) -> SerdesNode<T?>,

        read Instance: SerdesNode<Instance>,
        read Instance24: SerdesNode<Instance>,
        read SerInstance: <T>(ClassName: T | keyof<Instances> | "", Schema: { [string]: any }) -> SerdesNode<GetInstanceType<T, Instances, Instance>>,
        read CFrame: SerdesNode<CFrame>,
        read QCFrame: SerdesNode<CFrame>,
        read CFrameF16: SerdesNode<CFrame>,
        read CFrameF24: SerdesNode<CFrame>,
        read QCFrameF16: SerdesNode<CFrame>,
        read QCFrameF24: SerdesNode<CFrame>,
        read Color3: SerdesNode<Color3>,
        read Enum: <T>(EnumType: T & Enum) -> SerdesNode<GetEnumItem<T>>,
        read Enum8: <T>(EnumType: T & Enum) -> SerdesNode<GetEnumItem<T>>
    },
}

---------------------------------------------------------
-- STATE
---------------------------------------------------------
local WriteBuffer = buffer.create(BIG_BUFFER_SIZE) -- scratch buffer that is used during serialization
const FloatConverter = buffer.create(4) -- used to convert f32 to smaller precision version
local Cursor: number = 0
local ReadBuffer: buffer? = nil

const IdMap: { [number]: Instance } = setmetatable({}, { __mode = "v" })
const InstanceMap: { [Instance]: number } = setmetatable({}, { __mode = "k" })

---------------------------------------------------------
-- LOCALIZING BUILTINS
---------------------------------------------------------
const CreateTable = table.create
const NewInstance = Instance.new
const TaskSpawn = task.spawn
const TaskDelay = task.delay
const CoroutineYield = coroutine.yield
const CoroutineRunning = coroutine.running
const NewCFrame = CFrame.new
const NewUDim2 = UDim2.new
const FromUDim2Scale = UDim2.fromScale
const FromUDim2Offset = UDim2.fromOffset
const Pcall = pcall
const NewColor3 = Color3.fromRGB

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
        for _, Value in Array do
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
        for _, Value in Array do
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
        for _, Value in Array do
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
    const StructNode: SerdesNode<GetTypeFromTypeNodes<T>> = {}

    const Keys = {}
    local Idx = 0
    for Key in Tbl :: { [string]: SerdesNode<any> } do
        Idx += 1
        Keys[Idx] = Key
    end
    table.sort(Keys)

    const Writes = CreateTable<<Ser<any>>>(Idx)
    const Reads = CreateTable<<Des<any>>>(Idx)

    for i, Key in Keys do
        const Node = Tbl[Key]
        Writes[i] = Node[SER] :: Ser<any>
        Reads[i] = Node[DES] :: Des<any>
    end

    const function StructSer(Value: GetTypeFromTypeNodes<T> & { [string]: any })
        for i, Key in Keys do
            Writes[i](Value[Key])
        end
    end

    const function StructDes(): GetTypeFromTypeNodes<T>
        const Result = {}
        for i, Key in Keys do
            Result[Key] = Reads[i]()
        end
        return Result :: any
    end

    StructNode[SER] = StructSer
    StructNode[DES] = StructDes

    return StructNode
end

-- DeltaStruct (u8 present-count + u8 field ids; max 255 present fields)
--- Sparse struct: serializes present input keys only. `u8` present-count and field ids (max 255).
--- Field ids are 1-based into lexicographically sorted schema keys; entry order follows the input table.
--- @within Types
--- @tag Collections
--- @function DeltaStruct
--- @param fields {[string]: SerdesNode<any>} -- Field schemas keyed by name.
--- @return SerdesNode<any>

const function DeltaStruct<T>(Tbl: T & { [string]: SerdesNode<any> }): SerdesNode<Optional<GetTypeFromTypeNodes<T>> & { [string]: nil }>
    const DeltaStructNode: SerdesNode<Optional<GetTypeFromTypeNodes<T>> & { [string]: nil }> = {}

    const Keys = {}
    local Idx = 0
    for Key in Tbl :: { [string]: SerdesNode<any> } do
        Idx += 1
        Keys[Idx] = Key
    end
    table.sort(Keys)

    const Writes = CreateTable<<Ser<any>>>(Idx)
    const Reads = CreateTable<<Des<any>>>(Idx)
    const Lookup: { [string]: number } = {}

    for i, Key in Keys do
        const Node = Tbl[Key]
        Writes[i] = Node[SER] :: Ser<any>
        Reads[i] = Node[DES] :: Des<any>
        Lookup[Key] = i
    end

    const function DeltaStructSer(Value: Optional<GetTypeFromTypeNodes<T>> & { [string]: nil })
        const Cur = Cursor
        const Buf = WriteBuffer
        Cursor = Cur + 1
        local Len = 0
        for Key, Field in Value :: { [string]: any } do
            const Id = Lookup[Key]
            Len += 1
            const Curs = Cursor
            buffer.writeu8(Buf, Curs, Id)
            Cursor = Curs + 1
            Writes[Id](Field)
        end
        buffer.writeu8(Buf, Cur, Len)
    end

    const function DeltaStructDes(): Optional<GetTypeFromTypeNodes<T>> & { [string]: nil }
        const Result = {}
        const Buf = ReadBuffer :: buffer
        local Cur = Cursor
        const Len = buffer.readu8(Buf, Cur)
        Cursor = Cur + 1
        for _ = 1, Len do
            Cur = Cursor
            const Id = buffer.readu8(Buf, Cur)
            Cursor = Cur + 1
            const Key = Keys[Id]
            const Read = Reads[Id]

            Result[Key] = Read()
        end
        return Result :: any
    end

    DeltaStructNode[SER] = DeltaStructSer
    DeltaStructNode[DES] = DeltaStructDes

    return DeltaStructNode
end

-- DeltaStruct16 (u16 present-count + u16 field ids; max 65535 present fields)
--- Sparse struct: serializes present input keys only. `u16` present-count and field ids (max 65535).
--- Field ids are 1-based into lexicographically sorted schema keys; entry order follows the input table.
--- @within Types
--- @tag Collections
--- @function DeltaStruct16
--- @param fields {[string]: SerdesNode<any>} -- Field schemas keyed by name.
--- @return SerdesNode<any>

const function DeltaStruct16<T>(Tbl: T & { [string]: SerdesNode<any> }): SerdesNode<Optional<GetTypeFromTypeNodes<T>> & { [string]: nil }>
    const DeltaStruct16Node: SerdesNode<Optional<GetTypeFromTypeNodes<T>> & { [string]: nil }> = {}

    const Keys = {}
    local Idx = 0
    for Key in Tbl :: { [string]: SerdesNode<any> } do
        Idx += 1
        Keys[Idx] = Key
    end
    table.sort(Keys)

    const Writes = CreateTable<<Ser<any>>>(Idx)
    const Reads = CreateTable<<Des<any>>>(Idx)
    const Lookup: { [string]: number } = {}

    for i, Key in Keys do
        const Node = Tbl[Key]
        Writes[i] = Node[SER] :: Ser<any>
        Reads[i] = Node[DES] :: Des<any>
        Lookup[Key] = i
    end

    const function DeltaStruct16Ser(Value: Optional<GetTypeFromTypeNodes<T>> & { [string]: nil })
        const Cur = Cursor
        const Buf = WriteBuffer
        Cursor = Cur + 2
        local Len = 0
        for Key, Field in Value :: { [string]: any } do
            const Id = Lookup[Key]
            Len += 1
            const Curs = Cursor
            buffer.writeu16(Buf, Curs, Id)
            Cursor = Curs + 2
            Writes[Id](Field)
        end
        buffer.writeu16(Buf, Cur, Len)
    end

    const function DeltaStruct16Des(): Optional<GetTypeFromTypeNodes<T>> & { [string]: nil }
        const Result = {}
        const Buf = ReadBuffer :: buffer
        local Cur = Cursor
        const Len = buffer.readu16(Buf, Cur)
        Cursor = Cur + 2
        for _ = 1, Len do
            Cur = Cursor
            const Id = buffer.readu16(Buf, Cur)
            Cursor = Cur + 2
            const Key = Keys[Id]
            const Read = Reads[Id]

            Result[Key] = Read()
        end
        return Result :: any
    end

    DeltaStruct16Node[SER] = DeltaStruct16Ser
    DeltaStruct16Node[DES] = DeltaStruct16Des

    return DeltaStruct16Node
end

--- `Vector3` with three `f32` components. 12 bytes.
--- @within Types
--- @tag Vectors
--- @prop Vector SerdesNode<Vector3>

const Vector: SerdesNode<Vector3> = {} -- Vector (4x3 bytes, each element is F32)
do
    const function VectorSer(Value: Vector3)
        local Cur = Cursor
        const Buf = WriteBuffer
        buffer.writef32(Buf, Cur, Value.X)
        buffer.writef32(Buf, Cur + 4, Value.Y)
        buffer.writef32(Buf, Cur + 8, Value.Z)
        Cursor = Cur + 12
    end

    const function VectorDes(): Vector3
        local Cur = Cursor
        const Buf = ReadBuffer :: buffer
        const x = buffer.readf32(Buf, Cur)
        const y = buffer.readf32(Buf, Cur + 4)
        const z = buffer.readf32(Buf, Cur + 8)
        Cursor = Cur + 12

        return Vector3.new(x, y, z)
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
        for _, Value in Array do
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

--- `Vector3` with three `f24` components. 9 bytes.
--- @within Types
--- @tag Vectors
--- @prop VectorF24 SerdesNode<Vector3>

const VectorF24: SerdesNode<Vector3> = {} -- Vector (3x3 bytes, each element is F24)
do
    const function VectorF24Ser(Value: Vector3)
        local Cur = Cursor
        const Buf = WriteBuffer
        const Conv = FloatConverter

        -- inlined f24 3 times :sob: :pray:
        -- x
        do
            buffer.writef32(Conv, 0, Value.X)
            const Bits: number = buffer.readu32(Conv, 0)
            const Packed: number = bit32.rshift(Bits, 8)
            buffer.writeu16(Buf, Cur, bit32.band(Packed, 0xFFFF))
            buffer.writeu8(Buf, Cur + 2, bit32.rshift(Packed, 16))
        end
        -- y
        do
            buffer.writef32(Conv, 0, Value.Y)
            const Bits: number = buffer.readu32(Conv, 0)
            const Packed: number = bit32.rshift(Bits, 8)
            buffer.writeu16(Buf, Cur + 3, bit32.band(Packed, 0xFFFF))
            buffer.writeu8(Buf, Cur + 5, bit32.rshift(Packed, 16))
        end
        -- z
        do
            buffer.writef32(Conv, 0, Value.Z)
            const Bits: number = buffer.readu32(Conv, 0)
            const Packed: number = bit32.rshift(Bits, 8)
            buffer.writeu16(Buf, Cur + 6, bit32.band(Packed, 0xFFFF))
            buffer.writeu8(Buf, Cur + 8, bit32.rshift(Packed, 16))
        end

        Cursor = Cur + 9
    end

    const function VectorF24Des(): Vector3
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
        return Vector3.new(x, y, z)
    end

    VectorF24[SER] = VectorF24Ser
    VectorF24[DES] = VectorF24Des
end

--- `Vector3` with three `f16` components. 6 bytes.
--- @within Types
--- @tag Vectors
--- @prop VectorF16 SerdesNode<Vector3>

const VectorF16: SerdesNode<Vector3> = {} -- Vector (3x2 bytes, each element is F16)
do
    const function VectorF16Ser(Value: Vector3)
        local Cur = Cursor
        const Buf = WriteBuffer
        const Conv = FloatConverter

        -- x
        do
            buffer.writef32(Conv, 0, Value.X)
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
            buffer.writef32(Conv, 0, Value.Y)
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
            buffer.writef32(Conv, 0, Value.Z)
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

    const function VectorF16Des(): Vector3
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
        return Vector3.new(x, y, z)
    end

    VectorF16[SER] = VectorF16Ser
    VectorF16[DES] = VectorF16Des
end

--- `Vector3` with three `u16` components. 6 bytes.
--- @within Types
--- @tag Vectors
--- @prop VectorU16 SerdesNode<Vector3>

const VectorU16: SerdesNode<Vector3> = {} -- Vector (3x2 bytes, each element is U16)
do
    const function VectorU16Ser(Value: Vector3)
        local Cur = Cursor
        const Buf = WriteBuffer

        buffer.writeu16(Buf, Cur, Value.X)
        buffer.writeu16(Buf, Cur + 2, Value.Y)
        buffer.writeu16(Buf, Cur + 4, Value.Z)
        Cursor = Cur + 6
    end

    const function VectorU16Des(): Vector3
        local Cur = Cursor
        const Buf = ReadBuffer :: buffer

        const x = buffer.readu16(Buf, Cur)
        const y = buffer.readu16(Buf, Cur + 2)
        const z = buffer.readu16(Buf, Cur + 4)
        Cursor = Cur + 6

        return Vector3.new(x, y, z)
    end

    VectorU16[SER] = VectorU16Ser
    VectorU16[DES] = VectorU16Des
end

--- `Vector3` with three `i16` components. 6 bytes.
--- @within Types
--- @tag Vectors
--- @prop VectorI16 SerdesNode<Vector3>

const VectorI16: SerdesNode<Vector3> = {} -- Vector (3x2 bytes, each element is I16)
do
    const function VectorI16Ser(Value: Vector3)
        local Cur = Cursor
        const Buf = WriteBuffer

        buffer.writei16(Buf, Cur, Value.X)
        buffer.writei16(Buf, Cur + 2, Value.Y)
        buffer.writei16(Buf, Cur + 4, Value.Z)
        Cursor = Cur + 6
    end

    const function VectorI16Des(): Vector3
        local Cur = Cursor
        const Buf = ReadBuffer :: buffer

        const x = buffer.readi16(Buf, Cur)
        const y = buffer.readi16(Buf, Cur + 2)
        const z = buffer.readi16(Buf, Cur + 4)
        Cursor = Cur + 6

        return Vector3.new(x, y, z)
    end

    VectorI16[SER] = VectorI16Ser
    VectorI16[DES] = VectorI16Des
end

--- `Vector3` with three `u8` components. 3 bytes.
--- @within Types
--- @tag Vectors
--- @prop VectorU8 SerdesNode<Vector3>

const VectorU8: SerdesNode<Vector3> = {} -- Vector (3x1 bytes, each element is U8)
do
    const function VectorU8Ser(Value: Vector3)
        local Cur = Cursor
        const Buf = WriteBuffer

        buffer.writeu8(Buf, Cur, Value.X)
        buffer.writeu8(Buf, Cur + 1, Value.Y)
        buffer.writeu8(Buf, Cur + 2, Value.Z)
        Cursor = Cur + 3
    end

    const function VectorU8Des(): Vector3
        local Cur = Cursor
        const Buf = ReadBuffer :: buffer

        const x = buffer.readu8(Buf, Cur)
        const y = buffer.readu8(Buf, Cur + 1)
        const z = buffer.readu8(Buf, Cur + 2)
        Cursor = Cur + 3

        return Vector3.new(x, y, z)
    end

    VectorU8[SER] = VectorU8Ser
    VectorU8[DES] = VectorU8Des
end

--- RGB channels as three bytes. 3 bytes.
--- @within Types
--- @tag Roblox
--- @prop Color3 SerdesNode<Color3>

const Color3Node: SerdesNode<Color3> = {} -- Color3 (3 bytes, each element is U8)
do
    const function Color3Ser(Value: Color3)
        local Cur = Cursor
        const Buf = WriteBuffer

        buffer.writeu8(Buf, Cur, Value.R * 255)
        buffer.writeu8(Buf, Cur + 1, Value.G * 255)
        buffer.writeu8(Buf, Cur + 2, Value.B * 255)
        Cursor = Cur + 3
    end

    const function Color3Des(): Color3
        local Cur = Cursor
        const Buf = ReadBuffer :: buffer

        const r = buffer.readu8(Buf, Cur)
        const g = buffer.readu8(Buf, Cur + 1)
        const b = buffer.readu8(Buf, Cur + 2)
        Cursor = Cur + 3

        return NewColor3(r, g, b)
    end

    Color3Node[SER] = Color3Ser
    Color3Node[DES] = Color3Des
end

--- `Vector3` with three `i8` components. 3 bytes.
--- @within Types
--- @tag Vectors
--- @prop VectorI8 SerdesNode<Vector3>

const VectorI8: SerdesNode<Vector3> = {} -- Vector (3x1 bytes, each element is I8)
do
    const function VectorI8Ser(Value: Vector3)
        local Cur = Cursor
        const Buf = WriteBuffer

        buffer.writei8(Buf, Cur, Value.X)
        buffer.writei8(Buf, Cur + 1, Value.Y)
        buffer.writei8(Buf, Cur + 2, Value.Z)
        Cursor = Cur + 3
    end

    const function VectorI8Des(): Vector3
        local Cur = Cursor
        const Buf = ReadBuffer :: buffer

        const x = buffer.readi8(Buf, Cur)
        const y = buffer.readi8(Buf, Cur + 1)
        const z = buffer.readi8(Buf, Cur + 2)
        Cursor = Cur + 3

        return Vector3.new(x, y, z)
    end

    VectorI8[SER] = VectorI8Ser
    VectorI8[DES] = VectorI8Des
end

--- `Vector3` with three `u24` components. 9 bytes.
--- @within Types
--- @tag Vectors
--- @prop VectorU24 SerdesNode<Vector3>

const VectorU24: SerdesNode<Vector3> = {} -- Vector (3x3 bytes, each element is U24)
do
    const function VectorU24Ser(Value: Vector3)
        local Cur = Cursor
        const Buf = WriteBuffer

        -- x
        do
            const x = Value.X
            buffer.writeu16(Buf, Cur, bit32.band(x, 0xFFFF))
            buffer.writeu8(Buf, Cur + 2, bit32.band(bit32.rshift(x, 16), 0xFF))
        end
        -- y
        do
            const y = Value.Y
            buffer.writeu16(Buf, Cur + 3, bit32.band(y, 0xFFFF))
            buffer.writeu8(Buf, Cur + 5, bit32.band(bit32.rshift(y, 16), 0xFF))
        end
        -- z
        do
            const z = Value.Z
            buffer.writeu16(Buf, Cur + 6, bit32.band(z, 0xFFFF))
            buffer.writeu8(Buf, Cur + 8, bit32.band(bit32.rshift(z, 16), 0xFF))
        end

        Cursor = Cur + 9
    end

    const function VectorU24Des(): Vector3
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
        return Vector3.new(x, y, z)
    end

    VectorU24[SER] = VectorU24Ser
    VectorU24[DES] = VectorU24Des
end

--- `Vector3` with three `i24` components. 9 bytes.
--- @within Types
--- @tag Vectors
--- @prop VectorI24 SerdesNode<Vector3>

const VectorI24: SerdesNode<Vector3> = {} -- Vector (3x3 bytes, each element is I24)
do
    const function VectorI24Ser(Value: Vector3)
        local Cur = Cursor
        const Buf = WriteBuffer

        -- x
        do
            const x = Value.X
            buffer.writeu16(Buf, Cur, bit32.band(x, 0xFFFF))
            buffer.writeu8(Buf, Cur + 2, bit32.band(bit32.rshift(x, 16), 0xFF))
        end
        -- y
        do
            const y = Value.Y
            buffer.writeu16(Buf, Cur + 3, bit32.band(y, 0xFFFF))
            buffer.writeu8(Buf, Cur + 5, bit32.band(bit32.rshift(y, 16), 0xFF))
        end
        -- z
        do
            const z = Value.Z
            buffer.writeu16(Buf, Cur + 6, bit32.band(z, 0xFFFF))
            buffer.writeu8(Buf, Cur + 8, bit32.band(bit32.rshift(z, 16), 0xFF))
        end

        Cursor = Cur + 9
    end

    const function VectorI24Des(): Vector3
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
        return Vector3.new(x, y, z)
    end

    VectorI24[SER] = VectorI24Ser
    VectorI24[DES] = VectorI24Des
end

--- `Vector2` with two `f32` components. 8 bytes.
--- @within Types
--- @tag Vectors
--- @prop Vector2 SerdesNode<Vector2>

const Vector2Node: SerdesNode<Vector2> = {} -- Vector2 (2x4 bytes, each element is F32)
do
    const function Vector2Ser(Value: Vector2)
        local Cur = Cursor
        const Buf = WriteBuffer
        buffer.writef32(Buf, Cur, Value.X)
        buffer.writef32(Buf, Cur + 4, Value.Y)
        Cursor = Cur + 8
    end

    const function Vector2Des(): Vector2
        local Cur = Cursor
        const Buf = ReadBuffer :: buffer
        const x = buffer.readf32(Buf, Cur)
        const y = buffer.readf32(Buf, Cur + 4)
        Cursor = Cur + 8

        return Vector2.new(x, y)
    end

    Vector2Node[SER] = Vector2Ser
    Vector2Node[DES] = Vector2Des
end

--- `Vector2` with two `f24` components. 6 bytes.
--- @within Types
--- @tag Vectors
--- @prop Vector2F24 SerdesNode<Vector2>

const Vector2F24: SerdesNode<Vector2> = {} -- Vector2 (2x3 bytes, each element is F24)
do
    const function Vector2F24Ser(Value: Vector2)
        local Cur = Cursor
        const Buf = WriteBuffer
        const Conv = FloatConverter

        do
            buffer.writef32(Conv, 0, Value.X)
            const Bits: number = buffer.readu32(Conv, 0)
            const Packed: number = bit32.rshift(Bits, 8)
            buffer.writeu16(Buf, Cur, bit32.band(Packed, 0xFFFF))
            buffer.writeu8(Buf, Cur + 2, bit32.rshift(Packed, 16))
        end
        do
            buffer.writef32(Conv, 0, Value.Y)
            const Bits: number = buffer.readu32(Conv, 0)
            const Packed: number = bit32.rshift(Bits, 8)
            buffer.writeu16(Buf, Cur + 3, bit32.band(Packed, 0xFFFF))
            buffer.writeu8(Buf, Cur + 5, bit32.rshift(Packed, 16))
        end

        Cursor = Cur + 6
    end

    const function Vector2F24Des(): Vector2
        local Cur = Cursor
        const Buf = ReadBuffer :: buffer

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

        Cursor = Cur + 6
        return Vector2.new(x, y)
    end

    Vector2F24[SER] = Vector2F24Ser
    Vector2F24[DES] = Vector2F24Des
end

--- `Vector2` with two `f16` components. 4 bytes.
--- @within Types
--- @tag Vectors
--- @prop Vector2F16 SerdesNode<Vector2>

const Vector2F16: SerdesNode<Vector2> = {} -- Vector2 (2x2 bytes, each element is F16)
do
    const function Vector2F16Ser(Value: Vector2)
        local Cur = Cursor
        const Buf = WriteBuffer
        const Conv = FloatConverter

        do
            buffer.writef32(Conv, 0, Value.X)
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
        do
            buffer.writef32(Conv, 0, Value.Y)
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

        Cursor = Cur + 4
    end

    const function Vector2F16Des(): Vector2
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

        Cursor = Cur + 4
        return Vector2.new(x, y)
    end

    Vector2F16[SER] = Vector2F16Ser
    Vector2F16[DES] = Vector2F16Des
end

--- `Vector2` with two `u16` components. 4 bytes.
--- @within Types
--- @tag Vectors
--- @prop Vector2U16 SerdesNode<Vector2>

const Vector2U16: SerdesNode<Vector2> = {} -- Vector2 (2x2 bytes, each element is U16)
do
    const function Vector2U16Ser(Value: Vector2)
        local Cur = Cursor
        const Buf = WriteBuffer
        buffer.writeu16(Buf, Cur, Value.X)
        buffer.writeu16(Buf, Cur + 2, Value.Y)
        Cursor = Cur + 4
    end

    const function Vector2U16Des(): Vector2
        local Cur = Cursor
        const Buf = ReadBuffer :: buffer
        const x = buffer.readu16(Buf, Cur)
        const y = buffer.readu16(Buf, Cur + 2)
        Cursor = Cur + 4

        return Vector2.new(x, y)
    end

    Vector2U16[SER] = Vector2U16Ser
    Vector2U16[DES] = Vector2U16Des
end

--- `Vector2` with two `i16` components. 4 bytes.
--- @within Types
--- @tag Vectors
--- @prop Vector2I16 SerdesNode<Vector2>

const Vector2I16: SerdesNode<Vector2> = {} -- Vector2 (2x2 bytes, each element is I16)
do
    const function Vector2I16Ser(Value: Vector2)
        local Cur = Cursor
        const Buf = WriteBuffer
        buffer.writei16(Buf, Cur, Value.X)
        buffer.writei16(Buf, Cur + 2, Value.Y)
        Cursor = Cur + 4
    end

    const function Vector2I16Des(): Vector2
        local Cur = Cursor
        const Buf = ReadBuffer :: buffer
        const x = buffer.readi16(Buf, Cur)
        const y = buffer.readi16(Buf, Cur + 2)
        Cursor = Cur + 4

        return Vector2.new(x, y)
    end

    Vector2I16[SER] = Vector2I16Ser
    Vector2I16[DES] = Vector2I16Des
end

--- `Vector2` with two `u8` components. 2 bytes.
--- @within Types
--- @tag Vectors
--- @prop Vector2U8 SerdesNode<Vector2>

const Vector2U8: SerdesNode<Vector2> = {} -- Vector2 (2x1 bytes, each element is U8)
do
    const function Vector2U8Ser(Value: Vector2)
        local Cur = Cursor
        const Buf = WriteBuffer
        buffer.writeu8(Buf, Cur, Value.X)
        buffer.writeu8(Buf, Cur + 1, Value.Y)
        Cursor = Cur + 2
    end

    const function Vector2U8Des(): Vector2
        local Cur = Cursor
        const Buf = ReadBuffer :: buffer
        const x = buffer.readu8(Buf, Cur)
        const y = buffer.readu8(Buf, Cur + 1)
        Cursor = Cur + 2

        return Vector2.new(x, y)
    end

    Vector2U8[SER] = Vector2U8Ser
    Vector2U8[DES] = Vector2U8Des
end

--- `Vector2` with two `i8` components. 2 bytes.
--- @within Types
--- @tag Vectors
--- @prop Vector2I8 SerdesNode<Vector2>

const Vector2I8: SerdesNode<Vector2> = {} -- Vector2 (2x1 bytes, each element is I8)
do
    const function Vector2I8Ser(Value: Vector2)
        local Cur = Cursor
        const Buf = WriteBuffer
        buffer.writei8(Buf, Cur, Value.X)
        buffer.writei8(Buf, Cur + 1, Value.Y)
        Cursor = Cur + 2
    end

    const function Vector2I8Des(): Vector2
        local Cur = Cursor
        const Buf = ReadBuffer :: buffer
        const x = buffer.readi8(Buf, Cur)
        const y = buffer.readi8(Buf, Cur + 1)
        Cursor = Cur + 2

        return Vector2.new(x, y)
    end

    Vector2I8[SER] = Vector2I8Ser
    Vector2I8[DES] = Vector2I8Des
end

--- `Vector2` with two `u24` components. 6 bytes.
--- @within Types
--- @tag Vectors
--- @prop Vector2U24 SerdesNode<Vector2>

const Vector2U24: SerdesNode<Vector2> = {} -- Vector2 (2x3 bytes, each element is U24)
do
    const function Vector2U24Ser(Value: Vector2)
        local Cur = Cursor
        const Buf = WriteBuffer

        do
            const x = Value.X
            buffer.writeu16(Buf, Cur, bit32.band(x, 0xFFFF))
            buffer.writeu8(Buf, Cur + 2, bit32.band(bit32.rshift(x, 16), 0xFF))
        end
        do
            const y = Value.Y
            buffer.writeu16(Buf, Cur + 3, bit32.band(y, 0xFFFF))
            buffer.writeu8(Buf, Cur + 5, bit32.band(bit32.rshift(y, 16), 0xFF))
        end

        Cursor = Cur + 6
    end

    const function Vector2U24Des(): Vector2
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

        Cursor = Cur + 6
        return Vector2.new(x, y)
    end

    Vector2U24[SER] = Vector2U24Ser
    Vector2U24[DES] = Vector2U24Des
end

--- `Vector2` with two `i24` components. 6 bytes.
--- @within Types
--- @tag Vectors
--- @prop Vector2I24 SerdesNode<Vector2>

const Vector2I24: SerdesNode<Vector2> = {} -- Vector2 (2x3 bytes, each element is I24)
do
    const function Vector2I24Ser(Value: Vector2)
        local Cur = Cursor
        const Buf = WriteBuffer

        do
            const x = Value.X
            buffer.writeu16(Buf, Cur, bit32.band(x, 0xFFFF))
            buffer.writeu8(Buf, Cur + 2, bit32.band(bit32.rshift(x, 16), 0xFF))
        end
        do
            const y = Value.Y
            buffer.writeu16(Buf, Cur + 3, bit32.band(y, 0xFFFF))
            buffer.writeu8(Buf, Cur + 5, bit32.band(bit32.rshift(y, 16), 0xFF))
        end

        Cursor = Cur + 6
    end

    const function Vector2I24Des(): Vector2
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

        Cursor = Cur + 6
        return Vector2.new(x, y)
    end

    Vector2I24[SER] = Vector2I24Ser
    Vector2I24[DES] = Vector2I24Des
end

--- Full `UDim2` as four `f32` values. 16 bytes.
--- @within Types
--- @tag Roblox
--- @prop UDim2 SerdesNode<UDim2>

const UDim2Node: SerdesNode<UDim2> = {} -- UDim2 (4x4 bytes, each element is F32)
do
    const function UDim2Ser(Value: UDim2)
        local Cur = Cursor
        const Buf = WriteBuffer
        buffer.writef32(Buf, Cur, Value.X.Scale)
        buffer.writef32(Buf, Cur + 4, Value.X.Offset)
        buffer.writef32(Buf, Cur + 8, Value.Y.Scale)
        buffer.writef32(Buf, Cur + 12, Value.Y.Offset)
        Cursor = Cur + 16
    end

    const function UDim2Des(): UDim2
        local Cur = Cursor
        const Buf = ReadBuffer :: buffer
        const xScale = buffer.readf32(Buf, Cur)
        const xOffset = buffer.readf32(Buf, Cur + 4)
        const yScale = buffer.readf32(Buf, Cur + 8)
        const yOffset = buffer.readf32(Buf, Cur + 12)
        Cursor = Cur + 16

        return NewUDim2(xScale, xOffset, yScale, yOffset)
    end

    UDim2Node[SER] = UDim2Ser
    UDim2Node[DES] = UDim2Des
end

--- Two `f32` scale components. 8 bytes.
--- @within Types
--- @tag Roblox
--- @prop UDim2Scale SerdesNode<UDim2>

const UDim2Scale: SerdesNode<UDim2> = {} -- UDim2 scale only (2x4 bytes, each element is F32)
do
    const function UDim2ScaleSer(Value: UDim2)
        local Cur = Cursor
        const Buf = WriteBuffer
        buffer.writef32(Buf, Cur, Value.X.Scale)
        buffer.writef32(Buf, Cur + 4, Value.Y.Scale)
        Cursor = Cur + 8
    end

    const function UDim2ScaleDes(): UDim2
        local Cur = Cursor
        const Buf = ReadBuffer :: buffer
        const xScale = buffer.readf32(Buf, Cur)
        const yScale = buffer.readf32(Buf, Cur + 4)
        Cursor = Cur + 8

        return FromUDim2Scale(xScale, yScale)
    end

    UDim2Scale[SER] = UDim2ScaleSer
    UDim2Scale[DES] = UDim2ScaleDes
end

--- Two `f32` offset components. 8 bytes.
--- @within Types
--- @tag Roblox
--- @prop UDim2Offset SerdesNode<UDim2>

const UDim2Offset: SerdesNode<UDim2> = {} -- UDim2 offset only (2x4 bytes, each element is F32)
do
    const function UDim2OffsetSer(Value: UDim2)
        local Cur = Cursor
        const Buf = WriteBuffer
        buffer.writef32(Buf, Cur, Value.X.Offset)
        buffer.writef32(Buf, Cur + 4, Value.Y.Offset)
        Cursor = Cur + 8
    end

    const function UDim2OffsetDes(): UDim2
        local Cur = Cursor
        const Buf = ReadBuffer :: buffer
        const xOffset = buffer.readf32(Buf, Cur)
        const yOffset = buffer.readf32(Buf, Cur + 4)
        Cursor = Cur + 8

        return FromUDim2Offset(xOffset, yOffset)
    end

    UDim2Offset[SER] = UDim2OffsetSer
    UDim2Offset[DES] = UDim2OffsetDes
end

--- Two `i16` offset components. 4 bytes.
--- @within Types
--- @tag Roblox
--- @prop UDim2OffsetI16 SerdesNode<UDim2>

const UDim2OffsetI16: SerdesNode<UDim2> = {} -- UDim2 offset only (2x2 bytes, each element is I16)
do
    const function UDim2OffsetI16Ser(Value: UDim2)
        local Cur = Cursor
        const Buf = WriteBuffer
        buffer.writei16(Buf, Cur, Value.X.Offset)
        buffer.writei16(Buf, Cur + 2, Value.Y.Offset)
        Cursor = Cur + 4
    end

    const function UDim2OffsetI16Des(): UDim2
        local Cur = Cursor
        const Buf = ReadBuffer :: buffer
        const xOffset = buffer.readi16(Buf, Cur)
        const yOffset = buffer.readi16(Buf, Cur + 2)
        Cursor = Cur + 4

        return FromUDim2Offset(xOffset, yOffset)
    end

    UDim2OffsetI16[SER] = UDim2OffsetI16Ser
    UDim2OffsetI16[DES] = UDim2OffsetI16Des
end

--- Two `f24` scale components. 6 bytes.
--- @within Types
--- @tag Roblox
--- @prop UDim2ScaleF24 SerdesNode<UDim2>

const UDim2ScaleF24: SerdesNode<UDim2> = {} -- UDim2 scale only (2x3 bytes, each element is F24)
do
    const function UDim2ScaleF24Ser(Value: UDim2)
        local Cur = Cursor
        const Buf = WriteBuffer
        const Conv = FloatConverter

        do
            buffer.writef32(Conv, 0, Value.X.Scale)
            const Bits: number = buffer.readu32(Conv, 0)
            const Packed: number = bit32.rshift(Bits, 8)
            buffer.writeu16(Buf, Cur, bit32.band(Packed, 0xFFFF))
            buffer.writeu8(Buf, Cur + 2, bit32.rshift(Packed, 16))
        end
        do
            buffer.writef32(Conv, 0, Value.Y.Scale)
            const Bits: number = buffer.readu32(Conv, 0)
            const Packed: number = bit32.rshift(Bits, 8)
            buffer.writeu16(Buf, Cur + 3, bit32.band(Packed, 0xFFFF))
            buffer.writeu8(Buf, Cur + 5, bit32.rshift(Packed, 16))
        end

        Cursor = Cur + 6
    end

    const function UDim2ScaleF24Des(): UDim2
        local Cur = Cursor
        const Buf = ReadBuffer :: buffer

        local xScale = 0
        do
            const b1: number = buffer.readu16(Buf :: buffer, Cur)
            const b2: number = buffer.readu8(Buf :: buffer, Cur + 2)
            const Packed: number = bit32.bor(b1, bit32.lshift(b2, 16))
            const Exp8: number = bit32.band(bit32.rshift(Packed, 15), 0xFF)

            if Exp8 ~= 0 then
                const Sign: number = bit32.band(Packed, 0x800000)
                if Exp8 == 255 then
                    xScale = if Sign == 0 then MathHuge else NMathHuge
                else
                    const Mant15: number = bit32.band(Packed, 0x7FFF)
                    const Result: number = math.ldexp(1 + Mant15 / 32768, Exp8 - 127)
                    xScale = if Sign == 0 then Result else -Result
                end
            end
        end

        local yScale = 0
        do
            const b1: number = buffer.readu16(Buf :: buffer, Cur + 3)
            const b2: number = buffer.readu8(Buf :: buffer, Cur + 5)
            const Packed: number = bit32.bor(b1, bit32.lshift(b2, 16))
            const Exp8: number = bit32.band(bit32.rshift(Packed, 15), 0xFF)

            if Exp8 ~= 0 then
                const Sign: number = bit32.band(Packed, 0x800000)
                if Exp8 == 255 then
                    yScale = if Sign == 0 then MathHuge else NMathHuge
                else
                    const Mant15: number = bit32.band(Packed, 0x7FFF)
                    const Result: number = math.ldexp(1 + Mant15 / 32768, Exp8 - 127)
                    yScale = if Sign == 0 then Result else -Result
                end
            end
        end

        Cursor = Cur + 6
        return FromUDim2Scale(xScale, yScale)
    end

    UDim2ScaleF24[SER] = UDim2ScaleF24Ser
    UDim2ScaleF24[DES] = UDim2ScaleF24Des
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

-- Instance (2 bytes for id write, if your game has more than 65535 instances at once, consider using Instance24)
--- Instance reference as a `u16` `_VSID`. 2 bytes.
--- @within Types
--- @tag Roblox
--- @prop Instance SerdesNode<Instance>

const InstanceNode: SerdesNode<Instance> = {}
do
    const function InstanceSer(Value: Instance)
        const Id = InstanceMap[Value]
        if Id then
            const Cur = Cursor
            buffer.writeu16(WriteBuffer, Cur, Id)
            Cursor = Cur + 2
        else
            error(`Instance {Value:GetFullName()} not found in InstanceMap, make sure INSTANCE_SERIALIZATION_ENABLED is set to true`)
        end
    end

    const function InstanceDes(): Instance
        const Cur = Cursor
        const Id = buffer.readu16(ReadBuffer :: buffer, Cur)
        Cursor = Cur + 2
        const Value = IdMap[Id]
        if not Value then
            error(`Instance not found by id {Id}, make sure INSTANCE_SERIALIZATION_ENABLED is set to true and the Instance is reachable by this context.`)
        end

        return Value
    end

    InstanceNode[SER] = InstanceSer
    InstanceNode[DES] = InstanceDes
end

-- Instance24 (3 bytes for id write, max amount of instances at a time is 16_777_215)
--- Instance reference as a `u24` `_VSID`. 3 bytes.
--- @within Types
--- @tag Roblox
--- @prop Instance24 SerdesNode<Instance>

const Instance24: SerdesNode<Instance> = {}
do
    const function Instance24Ser(Value: Instance)
        const Id = InstanceMap[Value]
        if Id then
            const Buf = WriteBuffer
            local Cur = Cursor
            buffer.writeu16(Buf, Cur, bit32.band(Id, 0xFFFF))
            Cur += 2
            buffer.writeu8(Buf, Cur, bit32.band(bit32.rshift(Id, 16), 0xFF))
            Cursor = Cur + 1
        else
            error(`Instance {Value:GetFullName()} not found in InstanceMap, make sure INSTANCE_SERIALIZATION_ENABLED is set to true`)
        end
    end

    const function Instance24Des(): Instance
        local Cur = Cursor
        const Buf = ReadBuffer :: buffer
        const b1: number = buffer.readu16(Buf, Cur)
        Cur += 2
        const b2: number = buffer.readu8(Buf, Cur)
        Cursor = Cur + 1

        const Id = bit32.bor(b1, bit32.lshift(b2, 16))
        const Value = IdMap[Id]
        if not Value then
            error(`Instance not found by id {Id}, make sure INSTANCE_SERIALIZATION_ENABLED is set to true and the Instance is reachable by this context.`)
        end

        return Value
    end

    Instance24[SER] = Instance24Ser
    Instance24[DES] = Instance24Des
end

--- Position plus rotation matrix (`12 × f32`). 48 bytes.
--- @within Types
--- @tag Roblox
--- @prop CFrame SerdesNode<CFrame>

const CFrameNode: SerdesNode<CFrame> = {}
do
    const function CFrameSer(Value: CFrame)
        const 
        x: number, y: number, z: number, 
        R0: number, R01: number, R02: number, 
        R10: number, R11: number, R12: number, 
        R20: number, R21: number, R22: number 
        = Value:GetComponents()

        local Cur = Cursor
        const Buf = WriteBuffer

        buffer.writef32(Buf, Cur, x)
        buffer.writef32(Buf, Cur + 4, y)
        buffer.writef32(Buf, Cur + 8, z)
        buffer.writef32(Buf, Cur + 12, R0)
        buffer.writef32(Buf, Cur + 16, R01)
        buffer.writef32(Buf, Cur + 20, R02)
        buffer.writef32(Buf, Cur + 24, R10)
        buffer.writef32(Buf, Cur + 28, R11)
        buffer.writef32(Buf, Cur + 32, R12)
        buffer.writef32(Buf, Cur + 36, R20)
        buffer.writef32(Buf, Cur + 40, R21)
        buffer.writef32(Buf, Cur + 44, R22)
        Cursor = Cur + 48
    end
    
    const function CFrameDes(): CFrame
        local Cur = Cursor
        const Buf = ReadBuffer :: buffer

        const x = buffer.readf32(Buf, Cur)
        const y = buffer.readf32(Buf, Cur + 4)
        const z = buffer.readf32(Buf, Cur + 8)
        const R0 = buffer.readf32(Buf, Cur + 12)
        const R01 = buffer.readf32(Buf, Cur + 16)
        const R02 = buffer.readf32(Buf, Cur + 20)
        const R10 = buffer.readf32(Buf, Cur + 24)
        const R11 = buffer.readf32(Buf, Cur + 28)
        const R12 = buffer.readf32(Buf, Cur + 32)
        const R20 = buffer.readf32(Buf, Cur + 36)
        const R21 = buffer.readf32(Buf, Cur + 40)
        const R22 = buffer.readf32(Buf, Cur + 44)
        Cursor = Cur + 48

        return NewCFrame(x, y, z, R0, R01, R02, R10, R11, R12, R20, R21, R22)
    end

    CFrameNode[SER] = CFrameSer
    CFrameNode[DES] = CFrameDes
end

--- Position plus quaternion (`7 × f32`). 28 bytes.
--- @within Types
--- @tag Roblox
--- @prop QCFrame SerdesNode<CFrame>

const QCFrame: SerdesNode<CFrame> = {}
do  
    const function QCFrameSer(Value: CFrame)
        const Pos = Value.Position
        const Axis, Angle = Value:ToAxisAngle()
    
        const HalfAngle = Angle * 0.5
        const s = math.sin(HalfAngle)
    
        const qx = Axis.X * s
        const qy = Axis.Y * s
        const qz = Axis.Z * s
        const qw = math.cos(HalfAngle)
    
        const Cur = Cursor
        const Buf = WriteBuffer
    
        buffer.writef32(Buf, Cur, Pos.X)
        buffer.writef32(Buf, Cur + 4, Pos.Y)
        buffer.writef32(Buf, Cur + 8, Pos.Z)
        buffer.writef32(Buf, Cur + 12, qx)
        buffer.writef32(Buf, Cur + 16, qy)
        buffer.writef32(Buf, Cur + 20, qz)
        buffer.writef32(Buf, Cur + 24, qw)
    
        Cursor = Cur + 28
    end
    
    const function QCFrameDes(): CFrame
        local Cur = Cursor
        const Buf = ReadBuffer :: buffer

        const x = buffer.readf32(Buf, Cur)
        const y = buffer.readf32(Buf, Cur + 4)
        const z = buffer.readf32(Buf, Cur + 8)
        const qx = buffer.readf32(Buf, Cur + 12)
        const qy = buffer.readf32(Buf, Cur + 16)
        const qz = buffer.readf32(Buf, Cur + 20)
        const qw = buffer.readf32(Buf, Cur + 24)
        Cursor = Cur + 28

        return NewCFrame(x, y, z, qx, qy, qz, qw)
    end

    QCFrame[SER] = QCFrameSer
    QCFrame[DES] = QCFrameDes
end

--- Rotation matrix with `f24` components. 36 bytes.
--- @within Types
--- @tag Roblox
--- @prop CFrameF24 SerdesNode<CFrame>

const CFrameF24: SerdesNode<CFrame> = {}
do
    const function CFrameF24Ser(Value: CFrame)
        const
        x: number, y: number, z: number,
        R0: number, R01: number, R02: number,
        R10: number, R11: number, R12: number,
        R20: number, R21: number, R22: number
        = Value:GetComponents()

        local Cur = Cursor
        const Buf = WriteBuffer
        const Conv = FloatConverter

        do
            buffer.writef32(Conv, 0, x)
            const Bits: number = buffer.readu32(Conv, 0)
            const Packed: number = bit32.rshift(Bits, 8)
            buffer.writeu16(Buf, Cur, bit32.band(Packed, 0xFFFF))
            Cur += 2
            buffer.writeu8(Buf, Cur, bit32.rshift(Packed, 16))
            Cur += 1
        end
        do
            buffer.writef32(Conv, 0, y)
            const Bits: number = buffer.readu32(Conv, 0)
            const Packed: number = bit32.rshift(Bits, 8)
            buffer.writeu16(Buf, Cur, bit32.band(Packed, 0xFFFF))
            Cur += 2
            buffer.writeu8(Buf, Cur, bit32.rshift(Packed, 16))
            Cur += 1
        end
        do
            buffer.writef32(Conv, 0, z)
            const Bits: number = buffer.readu32(Conv, 0)
            const Packed: number = bit32.rshift(Bits, 8)
            buffer.writeu16(Buf, Cur, bit32.band(Packed, 0xFFFF))
            Cur += 2
            buffer.writeu8(Buf, Cur, bit32.rshift(Packed, 16))
            Cur += 1
        end
        do
            buffer.writef32(Conv, 0, R0)
            const Bits: number = buffer.readu32(Conv, 0)
            const Packed: number = bit32.rshift(Bits, 8)
            buffer.writeu16(Buf, Cur, bit32.band(Packed, 0xFFFF))
            Cur += 2
            buffer.writeu8(Buf, Cur, bit32.rshift(Packed, 16))
            Cur += 1
        end
        do
            buffer.writef32(Conv, 0, R01)
            const Bits: number = buffer.readu32(Conv, 0)
            const Packed: number = bit32.rshift(Bits, 8)
            buffer.writeu16(Buf, Cur, bit32.band(Packed, 0xFFFF))
            Cur += 2
            buffer.writeu8(Buf, Cur, bit32.rshift(Packed, 16))
            Cur += 1
        end
        do
            buffer.writef32(Conv, 0, R02)
            const Bits: number = buffer.readu32(Conv, 0)
            const Packed: number = bit32.rshift(Bits, 8)
            buffer.writeu16(Buf, Cur, bit32.band(Packed, 0xFFFF))
            Cur += 2
            buffer.writeu8(Buf, Cur, bit32.rshift(Packed, 16))
            Cur += 1
        end
        do
            buffer.writef32(Conv, 0, R10)
            const Bits: number = buffer.readu32(Conv, 0)
            const Packed: number = bit32.rshift(Bits, 8)
            buffer.writeu16(Buf, Cur, bit32.band(Packed, 0xFFFF))
            Cur += 2
            buffer.writeu8(Buf, Cur, bit32.rshift(Packed, 16))
            Cur += 1
        end
        do
            buffer.writef32(Conv, 0, R11)
            const Bits: number = buffer.readu32(Conv, 0)
            const Packed: number = bit32.rshift(Bits, 8)
            buffer.writeu16(Buf, Cur, bit32.band(Packed, 0xFFFF))
            Cur += 2
            buffer.writeu8(Buf, Cur, bit32.rshift(Packed, 16))
            Cur += 1
        end
        do
            buffer.writef32(Conv, 0, R12)
            const Bits: number = buffer.readu32(Conv, 0)
            const Packed: number = bit32.rshift(Bits, 8)
            buffer.writeu16(Buf, Cur, bit32.band(Packed, 0xFFFF))
            Cur += 2
            buffer.writeu8(Buf, Cur, bit32.rshift(Packed, 16))
            Cur += 1
        end
        do
            buffer.writef32(Conv, 0, R20)
            const Bits: number = buffer.readu32(Conv, 0)
            const Packed: number = bit32.rshift(Bits, 8)
            buffer.writeu16(Buf, Cur, bit32.band(Packed, 0xFFFF))
            Cur += 2
            buffer.writeu8(Buf, Cur, bit32.rshift(Packed, 16))
            Cur += 1
        end
        do
            buffer.writef32(Conv, 0, R21)
            const Bits: number = buffer.readu32(Conv, 0)
            const Packed: number = bit32.rshift(Bits, 8)
            buffer.writeu16(Buf, Cur, bit32.band(Packed, 0xFFFF))
            Cur += 2
            buffer.writeu8(Buf, Cur, bit32.rshift(Packed, 16))
            Cur += 1
        end
        do
            buffer.writef32(Conv, 0, R22)
            const Bits: number = buffer.readu32(Conv, 0)
            const Packed: number = bit32.rshift(Bits, 8)
            buffer.writeu16(Buf, Cur, bit32.band(Packed, 0xFFFF))
            Cur += 2
            buffer.writeu8(Buf, Cur, bit32.rshift(Packed, 16))
            Cur += 1
        end
        Cursor = Cur
    end

    const function CFrameF24Des(): CFrame
        local Cur = Cursor
        const Buf = ReadBuffer :: buffer

        local x = 0
        do
            const b1: number = buffer.readu16(Buf, Cur)
            Cur += 2
            const b2: number = buffer.readu8(Buf, Cur)
            Cur += 1
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
            const b1: number = buffer.readu16(Buf, Cur)
            Cur += 2
            const b2: number = buffer.readu8(Buf, Cur)
            Cur += 1
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
            const b1: number = buffer.readu16(Buf, Cur)
            Cur += 2
            const b2: number = buffer.readu8(Buf, Cur)
            Cur += 1
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
        local R0 = 0
        do
            const b1: number = buffer.readu16(Buf, Cur)
            Cur += 2
            const b2: number = buffer.readu8(Buf, Cur)
            Cur += 1
            const Packed: number = bit32.bor(b1, bit32.lshift(b2, 16))
            const Exp8: number = bit32.band(bit32.rshift(Packed, 15), 0xFF)
            if Exp8 ~= 0 then
                const Sign: number = bit32.band(Packed, 0x800000)
                if Exp8 == 255 then
                    R0 = if Sign == 0 then MathHuge else NMathHuge
                else
                    const Mant15: number = bit32.band(Packed, 0x7FFF)
                    const Result: number = math.ldexp(1 + Mant15 / 32768, Exp8 - 127)
                    R0 = if Sign == 0 then Result else -Result
                end
            end
        end
        local R01 = 0
        do
            const b1: number = buffer.readu16(Buf, Cur)
            Cur += 2
            const b2: number = buffer.readu8(Buf, Cur)
            Cur += 1
            const Packed: number = bit32.bor(b1, bit32.lshift(b2, 16))
            const Exp8: number = bit32.band(bit32.rshift(Packed, 15), 0xFF)
            if Exp8 ~= 0 then
                const Sign: number = bit32.band(Packed, 0x800000)
                if Exp8 == 255 then
                    R01 = if Sign == 0 then MathHuge else NMathHuge
                else
                    const Mant15: number = bit32.band(Packed, 0x7FFF)
                    const Result: number = math.ldexp(1 + Mant15 / 32768, Exp8 - 127)
                    R01 = if Sign == 0 then Result else -Result
                end
            end
        end
        local R02 = 0
        do
            const b1: number = buffer.readu16(Buf, Cur)
            Cur += 2
            const b2: number = buffer.readu8(Buf, Cur)
            Cur += 1
            const Packed: number = bit32.bor(b1, bit32.lshift(b2, 16))
            const Exp8: number = bit32.band(bit32.rshift(Packed, 15), 0xFF)
            if Exp8 ~= 0 then
                const Sign: number = bit32.band(Packed, 0x800000)
                if Exp8 == 255 then
                    R02 = if Sign == 0 then MathHuge else NMathHuge
                else
                    const Mant15: number = bit32.band(Packed, 0x7FFF)
                    const Result: number = math.ldexp(1 + Mant15 / 32768, Exp8 - 127)
                    R02 = if Sign == 0 then Result else -Result
                end
            end
        end
        local R10 = 0
        do
            const b1: number = buffer.readu16(Buf, Cur)
            Cur += 2
            const b2: number = buffer.readu8(Buf, Cur)
            Cur += 1
            const Packed: number = bit32.bor(b1, bit32.lshift(b2, 16))
            const Exp8: number = bit32.band(bit32.rshift(Packed, 15), 0xFF)
            if Exp8 ~= 0 then
                const Sign: number = bit32.band(Packed, 0x800000)
                if Exp8 == 255 then
                    R10 = if Sign == 0 then MathHuge else NMathHuge
                else
                    const Mant15: number = bit32.band(Packed, 0x7FFF)
                    const Result: number = math.ldexp(1 + Mant15 / 32768, Exp8 - 127)
                    R10 = if Sign == 0 then Result else -Result
                end
            end
        end
        local R11 = 0
        do
            const b1: number = buffer.readu16(Buf, Cur)
            Cur += 2
            const b2: number = buffer.readu8(Buf, Cur)
            Cur += 1
            const Packed: number = bit32.bor(b1, bit32.lshift(b2, 16))
            const Exp8: number = bit32.band(bit32.rshift(Packed, 15), 0xFF)
            if Exp8 ~= 0 then
                const Sign: number = bit32.band(Packed, 0x800000)
                if Exp8 == 255 then
                    R11 = if Sign == 0 then MathHuge else NMathHuge
                else
                    const Mant15: number = bit32.band(Packed, 0x7FFF)
                    const Result: number = math.ldexp(1 + Mant15 / 32768, Exp8 - 127)
                    R11 = if Sign == 0 then Result else -Result
                end
            end
        end
        local R12 = 0
        do
            const b1: number = buffer.readu16(Buf, Cur)
            Cur += 2
            const b2: number = buffer.readu8(Buf, Cur)
            Cur += 1
            const Packed: number = bit32.bor(b1, bit32.lshift(b2, 16))
            const Exp8: number = bit32.band(bit32.rshift(Packed, 15), 0xFF)
            if Exp8 ~= 0 then
                const Sign: number = bit32.band(Packed, 0x800000)
                if Exp8 == 255 then
                    R12 = if Sign == 0 then MathHuge else NMathHuge
                else
                    const Mant15: number = bit32.band(Packed, 0x7FFF)
                    const Result: number = math.ldexp(1 + Mant15 / 32768, Exp8 - 127)
                    R12 = if Sign == 0 then Result else -Result
                end
            end
        end
        local R20 = 0
        do
            const b1: number = buffer.readu16(Buf, Cur)
            Cur += 2
            const b2: number = buffer.readu8(Buf, Cur)
            Cur += 1
            const Packed: number = bit32.bor(b1, bit32.lshift(b2, 16))
            const Exp8: number = bit32.band(bit32.rshift(Packed, 15), 0xFF)
            if Exp8 ~= 0 then
                const Sign: number = bit32.band(Packed, 0x800000)
                if Exp8 == 255 then
                    R20 = if Sign == 0 then MathHuge else NMathHuge
                else
                    const Mant15: number = bit32.band(Packed, 0x7FFF)
                    const Result: number = math.ldexp(1 + Mant15 / 32768, Exp8 - 127)
                    R20 = if Sign == 0 then Result else -Result
                end
            end
        end
        local R21 = 0
        do
            const b1: number = buffer.readu16(Buf, Cur)
            Cur += 2
            const b2: number = buffer.readu8(Buf, Cur)
            Cur += 1
            const Packed: number = bit32.bor(b1, bit32.lshift(b2, 16))
            const Exp8: number = bit32.band(bit32.rshift(Packed, 15), 0xFF)
            if Exp8 ~= 0 then
                const Sign: number = bit32.band(Packed, 0x800000)
                if Exp8 == 255 then
                    R21 = if Sign == 0 then MathHuge else NMathHuge
                else
                    const Mant15: number = bit32.band(Packed, 0x7FFF)
                    const Result: number = math.ldexp(1 + Mant15 / 32768, Exp8 - 127)
                    R21 = if Sign == 0 then Result else -Result
                end
            end
        end
        local R22 = 0
        do
            const b1: number = buffer.readu16(Buf, Cur)
            Cur += 2
            const b2: number = buffer.readu8(Buf, Cur)
            Cur += 1
            const Packed: number = bit32.bor(b1, bit32.lshift(b2, 16))
            const Exp8: number = bit32.band(bit32.rshift(Packed, 15), 0xFF)
            if Exp8 ~= 0 then
                const Sign: number = bit32.band(Packed, 0x800000)
                if Exp8 == 255 then
                    R22 = if Sign == 0 then MathHuge else NMathHuge
                else
                    const Mant15: number = bit32.band(Packed, 0x7FFF)
                    const Result: number = math.ldexp(1 + Mant15 / 32768, Exp8 - 127)
                    R22 = if Sign == 0 then Result else -Result
                end
            end
        end
        Cursor = Cur
        return NewCFrame(x, y, z, R0, R01, R02, R10, R11, R12, R20, R21, R22)
    end

    CFrameF24[SER] = CFrameF24Ser
    CFrameF24[DES] = CFrameF24Des
end

--- Rotation matrix with `f16` components. 24 bytes.
--- @within Types
--- @tag Roblox
--- @prop CFrameF16 SerdesNode<CFrame>

const CFrameF16: SerdesNode<CFrame> = {}
do
    const function CFrameF16Ser(Value: CFrame)
        const
        x: number, y: number, z: number,
        R0: number, R01: number, R02: number,
        R10: number, R11: number, R12: number,
        R20: number, R21: number, R22: number
        = Value:GetComponents()

        local Cur = Cursor
        const Buf = WriteBuffer
        const Conv = FloatConverter

        do
            buffer.writef32(Conv, 0, x)
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
            Cur += 2
        end
        do
            buffer.writef32(Conv, 0, y)
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
            Cur += 2
        end
        do
            buffer.writef32(Conv, 0, z)
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
            Cur += 2
        end
        do
            buffer.writef32(Conv, 0, R0)
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
            Cur += 2
        end
        do
            buffer.writef32(Conv, 0, R01)
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
            Cur += 2
        end
        do
            buffer.writef32(Conv, 0, R02)
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
            Cur += 2
        end
        do
            buffer.writef32(Conv, 0, R10)
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
            Cur += 2
        end
        do
            buffer.writef32(Conv, 0, R11)
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
            Cur += 2
        end
        do
            buffer.writef32(Conv, 0, R12)
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
            Cur += 2
        end
        do
            buffer.writef32(Conv, 0, R20)
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
            Cur += 2
        end
        do
            buffer.writef32(Conv, 0, R21)
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
            Cur += 2
        end
        do
            buffer.writef32(Conv, 0, R22)
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
            Cur += 2
        end
        Cursor = Cur
    end

    const function CFrameF16Des(): CFrame
        local Cur = Cursor
        const Buf = ReadBuffer :: buffer

        local x = 0
        do
            const Packed: number = buffer.readu16(Buf, Cur)
            Cur += 2
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
            const Packed: number = buffer.readu16(Buf, Cur)
            Cur += 2
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
            const Packed: number = buffer.readu16(Buf, Cur)
            Cur += 2
            const Exp16: number = bit32.band(bit32.rshift(Packed, 10), 0x1F)
            if Exp16 ~= 0 then
                const Sign: number = bit32.band(Packed, 0x8000)
                const Mant10: number = bit32.band(Packed, 0x3FF)
                const Result: number = math.ldexp(1 + Mant10 / 1024, Exp16 - 15)
                z = if Sign == 0 then Result else -Result
            end
        end
        local R0 = 0
        do
            const Packed: number = buffer.readu16(Buf, Cur)
            Cur += 2
            const Exp16: number = bit32.band(bit32.rshift(Packed, 10), 0x1F)
            if Exp16 ~= 0 then
                const Sign: number = bit32.band(Packed, 0x8000)
                const Mant10: number = bit32.band(Packed, 0x3FF)
                const Result: number = math.ldexp(1 + Mant10 / 1024, Exp16 - 15)
                R0 = if Sign == 0 then Result else -Result
            end
        end
        local R01 = 0
        do
            const Packed: number = buffer.readu16(Buf, Cur)
            Cur += 2
            const Exp16: number = bit32.band(bit32.rshift(Packed, 10), 0x1F)
            if Exp16 ~= 0 then
                const Sign: number = bit32.band(Packed, 0x8000)
                const Mant10: number = bit32.band(Packed, 0x3FF)
                const Result: number = math.ldexp(1 + Mant10 / 1024, Exp16 - 15)
                R01 = if Sign == 0 then Result else -Result
            end
        end
        local R02 = 0
        do
            const Packed: number = buffer.readu16(Buf, Cur)
            Cur += 2
            const Exp16: number = bit32.band(bit32.rshift(Packed, 10), 0x1F)
            if Exp16 ~= 0 then
                const Sign: number = bit32.band(Packed, 0x8000)
                const Mant10: number = bit32.band(Packed, 0x3FF)
                const Result: number = math.ldexp(1 + Mant10 / 1024, Exp16 - 15)
                R02 = if Sign == 0 then Result else -Result
            end
        end
        local R10 = 0
        do
            const Packed: number = buffer.readu16(Buf, Cur)
            Cur += 2
            const Exp16: number = bit32.band(bit32.rshift(Packed, 10), 0x1F)
            if Exp16 ~= 0 then
                const Sign: number = bit32.band(Packed, 0x8000)
                const Mant10: number = bit32.band(Packed, 0x3FF)
                const Result: number = math.ldexp(1 + Mant10 / 1024, Exp16 - 15)
                R10 = if Sign == 0 then Result else -Result
            end
        end
        local R11 = 0
        do
            const Packed: number = buffer.readu16(Buf, Cur)
            Cur += 2
            const Exp16: number = bit32.band(bit32.rshift(Packed, 10), 0x1F)
            if Exp16 ~= 0 then
                const Sign: number = bit32.band(Packed, 0x8000)
                const Mant10: number = bit32.band(Packed, 0x3FF)
                const Result: number = math.ldexp(1 + Mant10 / 1024, Exp16 - 15)
                R11 = if Sign == 0 then Result else -Result
            end
        end
        local R12 = 0
        do
            const Packed: number = buffer.readu16(Buf, Cur)
            Cur += 2
            const Exp16: number = bit32.band(bit32.rshift(Packed, 10), 0x1F)
            if Exp16 ~= 0 then
                const Sign: number = bit32.band(Packed, 0x8000)
                const Mant10: number = bit32.band(Packed, 0x3FF)
                const Result: number = math.ldexp(1 + Mant10 / 1024, Exp16 - 15)
                R12 = if Sign == 0 then Result else -Result
            end
        end
        local R20 = 0
        do
            const Packed: number = buffer.readu16(Buf, Cur)
            Cur += 2
            const Exp16: number = bit32.band(bit32.rshift(Packed, 10), 0x1F)
            if Exp16 ~= 0 then
                const Sign: number = bit32.band(Packed, 0x8000)
                const Mant10: number = bit32.band(Packed, 0x3FF)
                const Result: number = math.ldexp(1 + Mant10 / 1024, Exp16 - 15)
                R20 = if Sign == 0 then Result else -Result
            end
        end
        local R21 = 0
        do
            const Packed: number = buffer.readu16(Buf, Cur)
            Cur += 2
            const Exp16: number = bit32.band(bit32.rshift(Packed, 10), 0x1F)
            if Exp16 ~= 0 then
                const Sign: number = bit32.band(Packed, 0x8000)
                const Mant10: number = bit32.band(Packed, 0x3FF)
                const Result: number = math.ldexp(1 + Mant10 / 1024, Exp16 - 15)
                R21 = if Sign == 0 then Result else -Result
            end
        end
        local R22 = 0
        do
            const Packed: number = buffer.readu16(Buf, Cur)
            Cur += 2
            const Exp16: number = bit32.band(bit32.rshift(Packed, 10), 0x1F)
            if Exp16 ~= 0 then
                const Sign: number = bit32.band(Packed, 0x8000)
                const Mant10: number = bit32.band(Packed, 0x3FF)
                const Result: number = math.ldexp(1 + Mant10 / 1024, Exp16 - 15)
                R22 = if Sign == 0 then Result else -Result
            end
        end
        Cursor = Cur
        return NewCFrame(x, y, z, R0, R01, R02, R10, R11, R12, R20, R21, R22)
    end

    CFrameF16[SER] = CFrameF16Ser
    CFrameF16[DES] = CFrameF16Des
end

--- Quaternion CFrame with `f24` components. 21 bytes.
--- @within Types
--- @tag Roblox
--- @prop QCFrameF24 SerdesNode<CFrame>

const QCFrameF24: SerdesNode<CFrame> = {}
do
    const function QCFrameF24Ser(Value: CFrame)
        const Pos = Value.Position
        const Axis, Angle = Value:ToAxisAngle()
        const HalfAngle = Angle * 0.5
        const s = math.sin(HalfAngle)
        const qx = Axis.X * s
        const qy = Axis.Y * s
        const qz = Axis.Z * s
        const qw = math.cos(HalfAngle)
        local Cur = Cursor
        const Buf = WriteBuffer
        const Conv = FloatConverter

        do
            buffer.writef32(Conv, 0, Pos.X)
            const Bits: number = buffer.readu32(Conv, 0)
            const Packed: number = bit32.rshift(Bits, 8)
            buffer.writeu16(Buf, Cur, bit32.band(Packed, 0xFFFF))
            Cur += 2
            buffer.writeu8(Buf, Cur, bit32.rshift(Packed, 16))
            Cur += 1
        end
        do
            buffer.writef32(Conv, 0, Pos.Y)
            const Bits: number = buffer.readu32(Conv, 0)
            const Packed: number = bit32.rshift(Bits, 8)
            buffer.writeu16(Buf, Cur, bit32.band(Packed, 0xFFFF))
            Cur += 2
            buffer.writeu8(Buf, Cur, bit32.rshift(Packed, 16))
            Cur += 1
        end
        do
            buffer.writef32(Conv, 0, Pos.Z)
            const Bits: number = buffer.readu32(Conv, 0)
            const Packed: number = bit32.rshift(Bits, 8)
            buffer.writeu16(Buf, Cur, bit32.band(Packed, 0xFFFF))
            Cur += 2
            buffer.writeu8(Buf, Cur, bit32.rshift(Packed, 16))
            Cur += 1
        end
        do
            buffer.writef32(Conv, 0, qx)
            const Bits: number = buffer.readu32(Conv, 0)
            const Packed: number = bit32.rshift(Bits, 8)
            buffer.writeu16(Buf, Cur, bit32.band(Packed, 0xFFFF))
            Cur += 2
            buffer.writeu8(Buf, Cur, bit32.rshift(Packed, 16))
            Cur += 1
        end
        do
            buffer.writef32(Conv, 0, qy)
            const Bits: number = buffer.readu32(Conv, 0)
            const Packed: number = bit32.rshift(Bits, 8)
            buffer.writeu16(Buf, Cur, bit32.band(Packed, 0xFFFF))
            Cur += 2
            buffer.writeu8(Buf, Cur, bit32.rshift(Packed, 16))
            Cur += 1
        end
        do
            buffer.writef32(Conv, 0, qz)
            const Bits: number = buffer.readu32(Conv, 0)
            const Packed: number = bit32.rshift(Bits, 8)
            buffer.writeu16(Buf, Cur, bit32.band(Packed, 0xFFFF))
            Cur += 2
            buffer.writeu8(Buf, Cur, bit32.rshift(Packed, 16))
            Cur += 1
        end
        do
            buffer.writef32(Conv, 0, qw)
            const Bits: number = buffer.readu32(Conv, 0)
            const Packed: number = bit32.rshift(Bits, 8)
            buffer.writeu16(Buf, Cur, bit32.band(Packed, 0xFFFF))
            Cur += 2
            buffer.writeu8(Buf, Cur, bit32.rshift(Packed, 16))
            Cur += 1
        end
        Cursor = Cur
    end

    const function QCFrameF24Des(): CFrame
        local Cur = Cursor
        const Buf = ReadBuffer :: buffer

        local x = 0
        do
            const b1: number = buffer.readu16(Buf, Cur)
            Cur += 2
            const b2: number = buffer.readu8(Buf, Cur)
            Cur += 1
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
            const b1: number = buffer.readu16(Buf, Cur)
            Cur += 2
            const b2: number = buffer.readu8(Buf, Cur)
            Cur += 1
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
            const b1: number = buffer.readu16(Buf, Cur)
            Cur += 2
            const b2: number = buffer.readu8(Buf, Cur)
            Cur += 1
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
        local qx = 0
        do
            const b1: number = buffer.readu16(Buf, Cur)
            Cur += 2
            const b2: number = buffer.readu8(Buf, Cur)
            Cur += 1
            const Packed: number = bit32.bor(b1, bit32.lshift(b2, 16))
            const Exp8: number = bit32.band(bit32.rshift(Packed, 15), 0xFF)
            if Exp8 ~= 0 then
                const Sign: number = bit32.band(Packed, 0x800000)
                if Exp8 == 255 then
                    qx = if Sign == 0 then MathHuge else NMathHuge
                else
                    const Mant15: number = bit32.band(Packed, 0x7FFF)
                    const Result: number = math.ldexp(1 + Mant15 / 32768, Exp8 - 127)
                    qx = if Sign == 0 then Result else -Result
                end
            end
        end
        local qy = 0
        do
            const b1: number = buffer.readu16(Buf, Cur)
            Cur += 2
            const b2: number = buffer.readu8(Buf, Cur)
            Cur += 1
            const Packed: number = bit32.bor(b1, bit32.lshift(b2, 16))
            const Exp8: number = bit32.band(bit32.rshift(Packed, 15), 0xFF)
            if Exp8 ~= 0 then
                const Sign: number = bit32.band(Packed, 0x800000)
                if Exp8 == 255 then
                    qy = if Sign == 0 then MathHuge else NMathHuge
                else
                    const Mant15: number = bit32.band(Packed, 0x7FFF)
                    const Result: number = math.ldexp(1 + Mant15 / 32768, Exp8 - 127)
                    qy = if Sign == 0 then Result else -Result
                end
            end
        end
        local qz = 0
        do
            const b1: number = buffer.readu16(Buf, Cur)
            Cur += 2
            const b2: number = buffer.readu8(Buf, Cur)
            Cur += 1
            const Packed: number = bit32.bor(b1, bit32.lshift(b2, 16))
            const Exp8: number = bit32.band(bit32.rshift(Packed, 15), 0xFF)
            if Exp8 ~= 0 then
                const Sign: number = bit32.band(Packed, 0x800000)
                if Exp8 == 255 then
                    qz = if Sign == 0 then MathHuge else NMathHuge
                else
                    const Mant15: number = bit32.band(Packed, 0x7FFF)
                    const Result: number = math.ldexp(1 + Mant15 / 32768, Exp8 - 127)
                    qz = if Sign == 0 then Result else -Result
                end
            end
        end
        local qw = 0
        do
            const b1: number = buffer.readu16(Buf, Cur)
            Cur += 2
            const b2: number = buffer.readu8(Buf, Cur)
            Cur += 1
            const Packed: number = bit32.bor(b1, bit32.lshift(b2, 16))
            const Exp8: number = bit32.band(bit32.rshift(Packed, 15), 0xFF)
            if Exp8 ~= 0 then
                const Sign: number = bit32.band(Packed, 0x800000)
                if Exp8 == 255 then
                    qw = if Sign == 0 then MathHuge else NMathHuge
                else
                    const Mant15: number = bit32.band(Packed, 0x7FFF)
                    const Result: number = math.ldexp(1 + Mant15 / 32768, Exp8 - 127)
                    qw = if Sign == 0 then Result else -Result
                end
            end
        end
        Cursor = Cur
        return NewCFrame(x, y, z, qx, qy, qz, qw)
    end

    QCFrameF24[SER] = QCFrameF24Ser
    QCFrameF24[DES] = QCFrameF24Des
end

--- Quaternion CFrame with `f16` components. 14 bytes.
--- @within Types
--- @tag Roblox
--- @prop QCFrameF16 SerdesNode<CFrame>

const QCFrameF16: SerdesNode<CFrame> = {}
do
    const function QCFrameF16Ser(Value: CFrame)
        const Pos = Value.Position
        const Axis, Angle = Value:ToAxisAngle()
        const HalfAngle = Angle * 0.5
        const s = math.sin(HalfAngle)
        const qx = Axis.X * s
        const qy = Axis.Y * s
        const qz = Axis.Z * s
        const qw = math.cos(HalfAngle)
        local Cur = Cursor
        const Buf = WriteBuffer
        const Conv = FloatConverter

        do
            buffer.writef32(Conv, 0, Pos.X)
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
            Cur += 2
        end
        do
            buffer.writef32(Conv, 0, Pos.Y)
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
            Cur += 2
        end
        do
            buffer.writef32(Conv, 0, Pos.Z)
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
            Cur += 2
        end
        do
            buffer.writef32(Conv, 0, qx)
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
            Cur += 2
        end
        do
            buffer.writef32(Conv, 0, qy)
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
            Cur += 2
        end
        do
            buffer.writef32(Conv, 0, qz)
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
            Cur += 2
        end
        do
            buffer.writef32(Conv, 0, qw)
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
            Cur += 2
        end
        Cursor = Cur
    end

    const function QCFrameF16Des(): CFrame
        local Cur = Cursor
        const Buf = ReadBuffer :: buffer

        local x = 0
        do
            const Packed: number = buffer.readu16(Buf, Cur)
            Cur += 2
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
            const Packed: number = buffer.readu16(Buf, Cur)
            Cur += 2
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
            const Packed: number = buffer.readu16(Buf, Cur)
            Cur += 2
            const Exp16: number = bit32.band(bit32.rshift(Packed, 10), 0x1F)
            if Exp16 ~= 0 then
                const Sign: number = bit32.band(Packed, 0x8000)
                const Mant10: number = bit32.band(Packed, 0x3FF)
                const Result: number = math.ldexp(1 + Mant10 / 1024, Exp16 - 15)
                z = if Sign == 0 then Result else -Result
            end
        end
        local qx = 0
        do
            const Packed: number = buffer.readu16(Buf, Cur)
            Cur += 2
            const Exp16: number = bit32.band(bit32.rshift(Packed, 10), 0x1F)
            if Exp16 ~= 0 then
                const Sign: number = bit32.band(Packed, 0x8000)
                const Mant10: number = bit32.band(Packed, 0x3FF)
                const Result: number = math.ldexp(1 + Mant10 / 1024, Exp16 - 15)
                qx = if Sign == 0 then Result else -Result
            end
        end
        local qy = 0
        do
            const Packed: number = buffer.readu16(Buf, Cur)
            Cur += 2
            const Exp16: number = bit32.band(bit32.rshift(Packed, 10), 0x1F)
            if Exp16 ~= 0 then
                const Sign: number = bit32.band(Packed, 0x8000)
                const Mant10: number = bit32.band(Packed, 0x3FF)
                const Result: number = math.ldexp(1 + Mant10 / 1024, Exp16 - 15)
                qy = if Sign == 0 then Result else -Result
            end
        end
        local qz = 0
        do
            const Packed: number = buffer.readu16(Buf, Cur)
            Cur += 2
            const Exp16: number = bit32.band(bit32.rshift(Packed, 10), 0x1F)
            if Exp16 ~= 0 then
                const Sign: number = bit32.band(Packed, 0x8000)
                const Mant10: number = bit32.band(Packed, 0x3FF)
                const Result: number = math.ldexp(1 + Mant10 / 1024, Exp16 - 15)
                qz = if Sign == 0 then Result else -Result
            end
        end
        local qw = 0
        do
            const Packed: number = buffer.readu16(Buf, Cur)
            Cur += 2
            const Exp16: number = bit32.band(bit32.rshift(Packed, 10), 0x1F)
            if Exp16 ~= 0 then
                const Sign: number = bit32.band(Packed, 0x8000)
                const Mant10: number = bit32.band(Packed, 0x3FF)
                const Result: number = math.ldexp(1 + Mant10 / 1024, Exp16 - 15)
                qw = if Sign == 0 then Result else -Result
            end
        end
        Cursor = Cur
        return NewCFrame(x, y, z, qx, qy, qz, qw)
    end

    QCFrameF16[SER] = QCFrameF16Ser
    QCFrameF16[DES] = QCFrameF16Des
end

--- Serializes selected properties from an existing instance.
--- @within Types
--- @tag Roblox
--- @function SerInstance
--- @param className string -- Instance class name.
--- @param schema {[string]: SerdesNode<any>} -- Property schemas keyed by name.
--- @return SerdesNode<Instance>

const function SerInstance<T>(ClassName: T | keyof<Instances> | "", Schema: { [string]: SerdesNode<any> }): SerdesNode<GetInstanceType<T, Instances, Instance>>
    const SerInstanceNode: SerdesNode<GetInstanceType<T, Instances, Instance>> = {}
    const Keys = {}
    local Idx = 0
    for Key in Schema do
        Idx += 1
        Keys[Idx] = Key
    end
    table.sort(Keys)

    const Writes = CreateTable<<Ser<any>>>(Idx)
    const Reads = CreateTable<<Des<any>>>(Idx)

    for i, Key in Keys do
        const Node = Schema[Key]
        Writes[i] = Node[SER] :: Ser<any>
        Reads[i] = Node[DES] :: Des<any>
    end

    const function SerInstanceSer(Value: Instance)
        for i, Key in Keys do
            Writes[i]((Value :: any)[Key])
        end
    end

    const function SerInstanceDes(): GetInstanceType<T, Instances, Instance>
        const Inst = NewInstance(ClassName) :: any
        for i, Key in Keys do
            Inst[Key] = Reads[i]()
        end

        return Inst
    end

    SerInstanceNode[SER] = SerInstanceSer
    SerInstanceNode[DES] = SerInstanceDes
    return SerInstanceNode
end

--- Enum item stored as a `u16` value.
--- @within Types
--- @tag Roblox
--- @function Enum
--- @param enumType Enum -- Enum to serialize.
--- @return SerdesNode<EnumItem>

const function EnumNode<T>(EnumType: T & Enum): SerdesNode<GetEnumItem<T>>
    const Node: SerdesNode<GetEnumItem<T>> = {}
    
    const function EnumSer(Value: EnumItem & GetEnumItem<T>)
        const Cur = Cursor
        buffer.writeu16(WriteBuffer, Cur, Value.Value)
        Cursor = Cur + 2
    end

    const function EnumDes(): GetEnumItem<T>
        const Cur = Cursor
        const Value = buffer.readu16(ReadBuffer :: buffer, Cursor)
        Cursor = Cur + 2
        return EnumType:FromValue(Value)
    end

    Node[SER] = EnumSer
    Node[DES] = EnumDes

    return Node
end

--- Enum item stored as a `u8` value.
--- @within Types
--- @tag Roblox
--- @function Enum8
--- @param enumType Enum -- Enum to serialize.
--- @return SerdesNode<EnumItem>

const function Enum8<T>(EnumType: T & Enum): SerdesNode<GetEnumItem<T>>
    const Node: SerdesNode<GetEnumItem<T>> = {}
    
    const function Enum8Ser(Value: EnumItem & GetEnumItem<T>)
        const Cur = Cursor
        buffer.writeu8(WriteBuffer, Cur, Value.Value)
        Cursor = Cur + 1
    end

    const function Enum8Des(): GetEnumItem<T>
        const Cur = Cursor
        const Value = buffer.readu8(ReadBuffer :: buffer, Cursor)
        Cursor = Cur + 1
        return EnumType:FromValue(Value)
    end

    Node[SER] = Enum8Ser
    Node[DES] = Enum8Des

    return Node
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
Types.DeltaStruct = DeltaStruct
Types.DeltaStruct16 = DeltaStruct16
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
Types.Vector2 = Vector2Node
Types.Vector2F24 = Vector2F24
Types.Vector2F16 = Vector2F16
Types.Vector2U16 = Vector2U16
Types.Vector2I16 = Vector2I16
Types.Vector2U8 = Vector2U8
Types.Vector2I8 = Vector2I8
Types.Vector2U24 = Vector2U24
Types.Vector2I24 = Vector2I24
Types.UDim2 = UDim2Node
Types.UDim2Scale = UDim2Scale
Types.UDim2Offset = UDim2Offset
Types.UDim2OffsetI16 = UDim2OffsetI16
Types.UDim2ScaleF24 = UDim2ScaleF24
Types.Bool = Bool
Types.BoolPacked = BoolPacked
Types.StringFixed = StringFixed
Types.Buffer = Buffer
Types.Buffer8 = Buffer8
Types.Buffer24 = Buffer24
Types.BufferFixed = BufferFixed
Types.Optional = Optional

Types.Instance = InstanceNode
Types.Instance24 = Instance24
Types.SerInstance = SerInstance
Types.CFrame = CFrameNode
Types.QCFrame = QCFrame
Types.CFrameF16 = CFrameF16
Types.CFrameF24 = CFrameF24
Types.QCFrameF16 = QCFrameF16
Types.QCFrameF24 = QCFrameF24
Types.Color3 = Color3Node
Types.Enum = EnumNode
Types.Enum8 = Enum8

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
--- serialization when your payload limit differs.
--- @tag Core
--- @param NewSize number -- New scratch-buffer size in bytes.
function VoidSentryUltimate.SetWriteBufferSize(NewSize: number): ()
    WriteBuffer = buffer.create(NewSize)
end

---------------------------------------------------------
-- INIT
---------------------------------------------------------
if INSTANCE_SERIALIZATION_ENABLED then
    if RunService:IsClient() then
        const function RetryGetAttribute(Co: thread, Descendant: Instance): ()
            TaskSpawn(Co, Descendant:GetAttribute(INSTANCE_ATTRIBUTE_NAME))
        end
        
        const function DeferFetch(Descendant: Instance): number?
            const Co = CoroutineRunning()
            TaskDelay(0, RetryGetAttribute, Co, Descendant)
            return CoroutineYield()
        end
        
        const function OnInstance(Descendant: Instance): ()
            local Success: boolean, Id: number? = Pcall(Descendant.GetAttribute :: (Instance, string) -> number?, Descendant, INSTANCE_ATTRIBUTE_NAME)
            if not Success then
                return
            end
            if not Id then
                Id = DeferFetch(Descendant)
                if not Id then
                    return
                end
            end
            IdMap[Id :: number] = Descendant
            InstanceMap[Descendant] = Id
        end

        for _, Descendant in game:GetDescendants() do
            TaskSpawn(OnInstance, Descendant)
        end
        game.DescendantAdded:Connect(OnInstance)
    else
        const FreeIds: { number } = {}
        local FreeIdsCount = 0
        local Total = 0

        const function OnInstance(Descendant: Instance): ()
            if FreeIdsCount ~= 0 then
                const Count = FreeIdsCount
                const Id = FreeIds[Count]
                FreeIds[Count] = nil
                FreeIdsCount = Count - 1

                const Success = Pcall(Descendant.SetAttribute, Descendant, INSTANCE_ATTRIBUTE_NAME, Id)
                if Success then
                    IdMap[Id] = Descendant
                    InstanceMap[Descendant] = Id
                end
            else
                const NewTotal = Total + 1
                const Success = Pcall(Descendant.SetAttribute, Descendant, INSTANCE_ATTRIBUTE_NAME, NewTotal)
        
                if Success then
                    Total = NewTotal
                    IdMap[Total] = Descendant
                    InstanceMap[Descendant] = NewTotal
                end
            end
        end

        const function OnRemoving(Descendant: Instance): ()
            const Id = InstanceMap[Descendant]
            if Id then
                table.insert(FreeIds, Id)
                FreeIdsCount += 1
            end
            -- the entries are cleaned up automatically
        end

        for _, Descendant in game:GetDescendants() do
            TaskSpawn(OnInstance, Descendant)
        end
        game.DescendantAdded:Connect(OnInstance)
        game.DescendantRemoving:Connect(OnRemoving)
    end
end

const Freeze = table.freeze
Freeze(Types)
Freeze(VoidSentryUltimate)

return VoidSentryUltimate :: Lib
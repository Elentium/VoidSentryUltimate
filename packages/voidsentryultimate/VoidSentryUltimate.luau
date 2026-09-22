--!native
--!optimize 2
--[[
    VoidSentryUltimate 
    [ V1.1.1 ]
    [ by IAMNOTULTRA3 a.k.a Elentium, Elite ]
    [ Apache-2.0 License ]

    Wally: "elentium/voidsentryultimate@1.1.1"
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

export type Ser<T> = (T, buffer, number) -> number
export type Des<T> = (buffer, number) -> (T, number)
export type SerdesNode<T> = {
	-- [1] = Ser
	-- [2] = Des
	[number]: any,
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

export type Schema<T> = {
    read Serialize: (Data: T) -> buffer,
    read SerializeWithOffset: (Data: T, Offset: number) -> buffer,
    read Deserialize: (Buffer: buffer) -> (T, number),
    read DeserializeWithOffset: (Buffer: buffer, Offset: number) -> (T, number),
    read Push: (Data: T, Buffer: buffer, Offset: number?) -> number,
    read DeltaSerialize: (Data: Optional<T>, Offset: number?) -> buffer,
    read DeltaDeserialize: (Buffer: buffer, Offset: number?) -> (Optional<T>, number),
    read DeltaPush: (Buffer: buffer, Data: Optional<T>, Offset: number) -> number
}

export type Lib = {
    read Serialize: <T>(Node: SerdesNode<any> & T, Data: GetTypeFromTypeNode<T>) -> buffer,
    read SerializeWithOffset: <T>(Node: SerdesNode<any> & T, Data: GetTypeFromTypeNode<T>, Offset: number) -> buffer,
    read Deserialize: <T>(Node: SerdesNode<T>, Buffer: buffer) -> (GetProperTypeFromUnion<T>, number),
    read DeserializeWithOffset: <T>(Node: SerdesNode<T>, Buffer: buffer, Offset: number) -> (GetProperTypeFromUnion<T>, number),
    read Push: <T>(Node: SerdesNode<any> & T, Data: GetTypeFromTypeNode<T>, Buffer: buffer, Offset: number?) -> number,
    read SetWriteBufferSize: (NewSize: number) -> (),
    read Schema: <T>(Tbl: T & { [string]: SerdesNode<any> }) -> Schema<GetTypeFromTypeNodes<T>>,

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
        read U40: SerdesNode<number>,
        read I40: SerdesNode<number>,
        read U48: SerdesNode<number>,
        read I48: SerdesNode<number>,
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
        read UDim2Quant: (ScaleMin: number, ScaleMax: number) -> SerdesNode<UDim2>,
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
        read CFrameQuant: SerdesNode<CFrame>,
        read CFrameQuant8: SerdesNode<CFrame>,
        read CFrameQuantF16: SerdesNode<CFrame>,
        read CFrameQuant8F16: SerdesNode<CFrame>,
        read Color3: SerdesNode<Color3>,
        read Enum: <T>(EnumType: T & Enum) -> SerdesNode<GetEnumItem<T>>,
        read Enum8: <T>(EnumType: T & Enum) -> SerdesNode<GetEnumItem<T>>
    },
}

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
const NewCFrameFromOrientation = CFrame.fromOrientation
const NewUDim2 = UDim2.new
const FromUDim2Scale = UDim2.fromScale
const FromUDim2Offset = UDim2.fromOffset
const Pcall = pcall
const NewColor3 = Color3.fromRGB
const TableFreeze = table.freeze
const CreateBuffer = buffer.create
const CopyBuffer = buffer.copy
const BufferLen = buffer.len

const MathHuge = math.huge
const NMathHuge = -math.huge
const Pi = math.pi
const DoublePi = Pi * 2
const HalfPi = Pi / 2

---------------------------------------------------------
-- STATE
---------------------------------------------------------
local WriteBuffer = CreateBuffer(BIG_BUFFER_SIZE) -- scratch buffer that is used during serialization
const FloatConverter = CreateBuffer(4) -- used to convert f32 to smaller precision version

const IdMap: { [number]: Instance } = {}
const InstanceMap: { [Instance]: number } = {}

---------------------------------------------------------
-- NODES
const I8: SerdesNode<number> = {}

do
	const function I8Ser(Value: number, Buf: buffer, Cur: number): number
		buffer.writei8(Buf, Cur, Value)
		Cur = Cur + 1
	
		return Cur
	end

	const function I8Des(Buf: buffer, Cur: number): (number, number)
		const Value = buffer.readi8(Buf, Cur)
		Cur = Cur + 1
		return Value, Cur
	end

	I8[SER] = I8Ser
	I8[DES] = I8Des
end

const U8: SerdesNode<number> = {}

do
	const function U8Ser(Value: number, Buf: buffer, Cur: number): number
		buffer.writeu8(Buf, Cur, Value)
		Cur = Cur + 1
	
		return Cur
	end

	const function U8Des(Buf: buffer, Cur: number): (number, number)
		const Value = buffer.readu8(Buf, Cur)
		Cur = Cur + 1
		return Value, Cur
	end

	U8[SER] = U8Ser
	U8[DES] = U8Des
end

const U16: SerdesNode<number> = {}

do
	const function U16Ser(Value: number, Buf: buffer, Cur: number): number
		buffer.writeu16(Buf, Cur, Value)
		Cur = Cur + 2
	
		return Cur
	end

	const function U16Des(Buf: buffer, Cur: number): (number, number)
		const Value = buffer.readu16(Buf, Cur)
		Cur = Cur + 2
		return Value, Cur
	end

	U16[SER] = U16Ser
	U16[DES] = U16Des
end

const I16: SerdesNode<number> = {}

do
	const function I16Ser(Value: number, Buf: buffer, Cur: number): number
		buffer.writei16(Buf, Cur, Value)
		Cur = Cur + 2
	
		return Cur
	end

	const function I16Des(Buf: buffer, Cur: number): (number, number)
		const Value = buffer.readi16(Buf, Cur)
		Cur = Cur + 2
		return Value, Cur
	end

	I16[SER] = I16Ser
	I16[DES] = I16Des
end

const U32: SerdesNode<number> = {}

do
	const function U32Ser(Value: number, Buf: buffer, Cur: number): number
		buffer.writeu32(Buf, Cur, Value)
		Cur = Cur + 4
	
		return Cur
	end

	const function U32Des(Buf: buffer, Cur: number): (number, number)
		const Value = buffer.readu32(Buf, Cur)
		Cur = Cur + 4
		return Value, Cur
	end

	U32[SER] = U32Ser
	U32[DES] = U32Des
end

const I32: SerdesNode<number> = {}

do
	const function I32Ser(Value: number, Buf: buffer, Cur: number): number
		buffer.writei32(Buf, Cur, Value)
		Cur = Cur + 4
	
		return Cur
	end

	const function I32Des(Buf: buffer, Cur: number): (number, number)
		const Value = buffer.readi32(Buf, Cur)
		Cur = Cur + 4
		return Value, Cur
	end

	I32[SER] = I32Ser
	I32[DES] = I32Des
end

const I40: SerdesNode<number> = {}

do
	const function I40Ser(Value: number, Buf: buffer, Cur: number): number
		buffer.writeu32(Buf, Cur, bit32.band(Value, 0xFFFFFFFF))
        buffer.writeu8(Buf, Cur + 4, bit32.band(Value // 0x100000000, 0xFF))
		return Cur + 5
	end

	const function I40Des(Buf: buffer, Cur: number): (number, number)
		const Low = buffer.readu32(Buf, Cur)
        const High = buffer.readu8(Buf, Cur + 4)
	    local Value = Low + High * 0x100000000
        if Value >= 0x8000000000 then
            Value -= 0x10000000000
        end
		return Value, Cur + 5
	end

	I40[SER] = I40Ser
	I40[DES] = I40Des
end

const U40: SerdesNode<number> = {}

do
	const function U40Ser(Value: number, Buf: buffer, Cur: number): number
		buffer.writeu32(Buf, Cur, bit32.band(Value, 0xFFFFFFFF))
        buffer.writeu8(Buf, Cur + 4, bit32.band(Value // 0x100000000, 0xFF))
		return Cur + 5
	end

	const function U40Des(Buf: buffer, Cur: number): (number, number)
		const Low = buffer.readu32(Buf, Cur)
        const High = buffer.readu8(Buf, Cur + 4)
	    const Value = Low + High * 0x100000000
		return Value, Cur + 5
	end

	U40[SER] = U40Ser
	U40[DES] = U40Des
end

const I48: SerdesNode<number> = {}

do
	const function I48Ser(Value: number, Buf: buffer, Cur: number): number
		buffer.writeu32(Buf, Cur, bit32.band(Value, 0xFFFFFFFF))
        buffer.writeu16(Buf, Cur + 4, bit32.band(Value // 0x100000000, 0xFFFF))
		return Cur + 6
	end

	const function I48Des(Buf: buffer, Cur: number): (number, number)
		const Low = buffer.readu32(Buf, Cur)
        const High = buffer.readu16(Buf, Cur + 4)
	    local Value = Low + High * 0x100000000
        if Value >= 0x800000000000 then
            Value -= 0x1000000000000
        end
		return Value, Cur + 6
	end

    I48[SER] = I48Ser
	I48[DES] = I48Des
end

const U48: SerdesNode<number> = {}

do
	const function U48Ser(Value: number, Buf: buffer, Cur: number): number
		buffer.writeu32(Buf, Cur, bit32.band(Value, 0xFFFFFFFF))
        buffer.writeu16(Buf, Cur + 4, bit32.band(Value // 0x100000000, 0xFFFF))
		return Cur + 6
	end

	const function U48Des(Buf: buffer, Cur: number): (number, number)
		const Low = buffer.readu32(Buf, Cur)
        const High = buffer.readu16(Buf, Cur + 4)
	    const Value = Low + High * 0x100000000
		return Value, Cur + 6
	end

    U48[SER] = U48Ser
	U48[DES] = U48Des
end

const F32: SerdesNode<number> = {}

do
	const function F32Ser(Value: number, Buf: buffer, Cur: number): number
		buffer.writef32(Buf, Cur, Value)
		Cur = Cur + 4
	
		return Cur
	end

	const function F32Des(Buf: buffer, Cur: number): (number, number)
		const Value = buffer.readf32(Buf, Cur)
		Cur = Cur + 4
		return Value, Cur
	end

	F32[SER] = F32Ser
	F32[DES] = F32Des
end

const F64: SerdesNode<number> = {}

do
	const function F64Ser(Value: number, Buf: buffer, Cur: number): number
		buffer.writef64(Buf, Cur, Value)
		Cur = Cur + 8
	
		return Cur
	end

	const function F64Des(Buf: buffer, Cur: number): (number, number)
		const Value = buffer.readf64(Buf, Cur)
		Cur = Cur + 8
		return Value, Cur
	end

	F64[SER] = F64Ser
	F64[DES] = F64Des
end

const String: SerdesNode<string> = {}

do
	const function StringSer(Value: string, Buf: buffer, Cur: number): number
        const Len = #Value
        buffer.writeu16(Buf, Cur, Len)
        Cur += 2
		buffer.writestring(Buf, Cur, Value)
		Cur = Cur + Len
	
        return Cur
	end

	const function StringDes(Buf: buffer, Cur: number): (string, number)
		const Len = buffer.readu16(Buf, Cur)
		Cur += 2
        const Value = buffer.readstring(Buf, Cur, Len)
        Cur = Cur + Len
		return Value, Cur
	end

	String[SER] = StringSer
	String[DES] = StringDes
end

const String8: SerdesNode<string> = {}

do
	const function String8Ser(Value: string, Buf: buffer, Cur: number): number
        const Len = #Value
        buffer.writeu8(Buf, Cur, Len)
        Cur += 1
		buffer.writestring(Buf, Cur, Value)
		Cur = Cur + Len
	
        return Cur
	end

	const function String8Des(Buf: buffer, Cur: number): (string, number)
		const Len = buffer.readu8(Buf, Cur)
		Cur += 1
        const Value = buffer.readstring(Buf, Cur, Len)
        Cur = Cur + Len
		return Value, Cur
	end

	String8[SER] = String8Ser
	String8[DES] = String8Des
end

-- StringFixed (fixed length)
const function StringFixed(Length: number): SerdesNode<string>
    const StringFixedNode: SerdesNode<string> = {}

    const function StringFixedSer(Value: string, Buf: buffer, Cur: number): number
		buffer.writestring(Buf, Cur, Value)
		Cur = Cur + Length
	
		return Cur
    end

	const function StringFixedDes(Buf: buffer, Cur: number): (string, number)
        const Value = buffer.readstring(Buf, Cur, Length)
        Cur = Cur + Length
		return Value, Cur
	end

	StringFixedNode[SER] = StringFixedSer
	StringFixedNode[DES] = StringFixedDes

    return StringFixedNode
end

-- Array (16 bits for length write, meaning max amount of elements in the array is 65535)
const function Array<T>(Node: SerdesNode<T>): SerdesNode<{ T }>
    const ArrayNode: SerdesNode<{ T }> = {}

    const Ser = Node[SER] :: Ser<T>
    const Des = Node[DES] :: Des<T>

    const function ArraySer(Array: { T }, Buf: buffer, Cur: number): number
        const Len = #Array
        buffer.writeu16(Buf, Cur, Len)
        Cur = Cur + 2
        const Ser = Ser
        for _, Value in Array do
            Cur = Ser(Value, Buf, Cur)
        end
    
        return Cur
    end

    const function ArrayDes(Buf: buffer, Cur: number): ({ T }, number)
        const Len = buffer.readu16(Buf, Cur)
        const Array = CreateTable<<T>>(Len)
        Cur = Cur + 2
        const Des = Des
        for i = 1, Len do
            Array[i], Cur = Des(Buf, Cur)
        end
        return Array, Cur
    end

    ArrayNode[SER] = ArraySer
    ArrayNode[DES] = ArrayDes

    return ArrayNode
end

-- Array8 (8 bits for length write, meaning max amount of elements in the array is 255)
const function Array8<T>(Node: SerdesNode<T>): SerdesNode<{ T }>
    const Array8Node: SerdesNode<{ T }> = {}

    const Ser = Node[SER] :: Ser<T>
    const Des = Node[DES] :: Des<T>

    const function Array8Ser(Array: { T }, Buf: buffer, Cur: number): number
        const Len = #Array
        buffer.writeu8(Buf, Cur, Len)
        Cur = Cur + 1
        const Ser = Ser
        for _, Value in Array do
            Cur = Ser(Value, Buf, Cur)
        end
    
        return Cur
    end

    const function Array8Des(Buf: buffer, Cur: number): ({ T }, number)
        const Len = buffer.readu8(Buf, Cur)
        const Array = CreateTable<<T>>(Len)
        Cur = Cur + 1
        const Des = Des
        for i = 1, Len do
            Array[i], Cur = Des(Buf, Cur)
        end
        return Array, Cur
    end

    Array8Node[SER] = Array8Ser
    Array8Node[DES] = Array8Des

    return Array8Node
end

-- Array24 (24 bits for length write, meaning max amount of elements in the array is 16_777_215)
const function Array24<T>(Node: SerdesNode<T>): SerdesNode<{ T }>
    const Array24Node: SerdesNode<{ T }> = {}

    const Ser = Node[SER] :: Ser<T>
    const Des = Node[DES] :: Des<T>

    const function Array24Ser(Array: { T }, Buf: buffer, Cur: number): number
        const Len = #Array
        buffer.writeu16(Buf, Cur, bit32.band(Len, 0xFFFF))
        buffer.writeu8(Buf, Cur + 2, bit32.band(bit32.rshift(Len, 16), 0xFF))
        Cur = Cur + 3
        const Ser = Ser
        for _, Value in Array do
            Cur = Ser(Value, Buf, Cur)
        end
    
        return Cur
    end

    const function Array24Des(Buf: buffer, Cur: number): ({ T }, number)
        const b1: number = buffer.readu16(Buf, Cur)
        const b2: number = buffer.readu8(Buf, Cur + 2)
        const Len = bit32.bor(b1, bit32.lshift(b2, 16))
        const Array = CreateTable<<T>>(Len)
        Cur = Cur + 3
        const Des = Des
        for i = 1, Len do
            Array[i], Cur = Des(Buf, Cur)
        end
        return Array, Cur
    end

    Array24Node[SER] = Array24Ser
    Array24Node[DES] = Array24Des

    return Array24Node
end

-- Struct (Pretty straightforward)
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

    const function StructSer(Value: GetTypeFromTypeNodes<T> & { [string]: any }, Buf: buffer, Cur: number): number
        const Writes = Writes
        for i, Key in Keys do
            Cur = Writes[i](Value[Key], Buf, Cur)
        end
    
        return Cur
    end

    const function StructDes(Buf: buffer, Cur: number): (GetTypeFromTypeNodes<T>, number)
        const Result = {}
        const Reads = Reads
        for i, Key in Keys do
            Result[Key], Cur = Reads[i](Buf, Cur)
        end
        return Result :: any, Cur
    end

    StructNode[SER] = StructSer
    StructNode[DES] = StructDes

    return StructNode
end

-- DeltaStruct (u8 present-count + u8 field ids; max 255 present fields)
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

    const function DeltaStructSer(Value: Optional<GetTypeFromTypeNodes<T>> & { [string]: nil }, Buf: buffer, Cur: number): number
        const Start = Cur
        Cur = Cur + 1
        local Len = 0
        const Lookup = Lookup
        const Writes = Writes
        for Key, Field in Value :: { [string]: any } do
            const Id = Lookup[Key]
            Len += 1
            buffer.writeu8(Buf, Cur, Id)
            Cur += 1
            Cur = Writes[Id](Field, Buf, Cur)
        end
        buffer.writeu8(Buf, Start, Len)
    
        return Cur
    end

    const function DeltaStructDes(Buf: buffer, Cur: number): (Optional<GetTypeFromTypeNodes<T>> & { [string]: nil }, number)
        const Result = {}
        const Len = buffer.readu8(Buf, Cur)
        const Keys = Keys
        const Reads = Reads
        Cur = Cur + 1
        for _ = 1, Len do
            const Id = buffer.readu8(Buf, Cur)
            Cur = Cur + 1
            const Key = Keys[Id]
            const Read = Reads[Id]

            Result[Key], Cur = Read(Buf, Cur)
        end
        return Result :: any, Cur
    end

    DeltaStructNode[SER] = DeltaStructSer
    DeltaStructNode[DES] = DeltaStructDes

    return DeltaStructNode
end

-- DeltaStruct16 (u16 present-count + u16 field ids; max 65535 present fields)
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

    const function DeltaStruct16Ser(Value: Optional<GetTypeFromTypeNodes<T>> & { [string]: nil }, Buf: buffer, Cur: number): number
        const Start = Cur
        Cur = Cur + 2
        local Len = 0
        const Lookup = Lookup
        const Writes = Writes
        for Key, Field in Value :: { [string]: any } do
            const Id = Lookup[Key]
            Len += 1
            buffer.writeu16(Buf, Cur, Id)
            Cur += 2
            Cur = Writes[Id](Field, Buf, Cur)
        end
        buffer.writeu16(Buf, Start, Len)
    
        return Cur
    end

    const function DeltaStruct16Des(Buf: buffer, Cur: number): (Optional<GetTypeFromTypeNodes<T>> & { [string]: nil }, number)
        const Result = {}
        const Len = buffer.readu16(Buf, Cur)
        Cur = Cur + 2
        const Keys = Keys
        const Reads = Reads
        for _ = 1, Len do
            const Id = buffer.readu16(Buf, Cur)
            Cur = Cur + 2
            const Key = Keys[Id]
            const Read = Reads[Id]

            Result[Key], Cur = Read(Buf, Cur)
        end
        return Result :: any, Cur
    end

    DeltaStruct16Node[SER] = DeltaStruct16Ser
    DeltaStruct16Node[DES] = DeltaStruct16Des

    return DeltaStruct16Node
end

const Vector: SerdesNode<Vector3> = {}
do
    const function VectorSer(Value: Vector3, Buf: buffer, Cur: number): number
        buffer.writef32(Buf, Cur, Value.X)
        buffer.writef32(Buf, Cur + 4, Value.Y)
        buffer.writef32(Buf, Cur + 8, Value.Z)
        Cur = Cur + 12
    
        return Cur
    end

    const function VectorDes(Buf: buffer, Cur: number): (Vector3, number)
        const x = buffer.readf32(Buf, Cur)
        const y = buffer.readf32(Buf, Cur + 4)
        const z = buffer.readf32(Buf, Cur + 8)
        Cur = Cur + 12

        return Vector3.new(x, y, z), Cur
    end

    Vector[SER] = VectorSer
    Vector[DES] = VectorDes
end

-- Map (16 bits for length write, meaning max amount of elements in the map is 65535)
const function Map<K, V>(KeyNode: SerdesNode<K>, ValueNode: SerdesNode<V>): SerdesNode<{ [K]: V }>
    const MapNode: SerdesNode<{ [K]: V }> = {}

    const KeySer = KeyNode[SER] :: Ser<K>
    const KeyDes = KeyNode[DES] :: Des<K>

    const ValueSer = ValueNode[SER] :: Ser<V>
    const ValueDes = ValueNode[DES] :: Des<V>

    const function MapSer(Map: { [K]: V }, Buf: buffer, Cur: number): number
        const Start = Cur
        local Len = 0
        Cur = Cur + 2
        const KeySer = KeySer
        const ValueSer = ValueSer
        for Key, Value in Map do
            Len += 1
            Cur = KeySer(Key, Buf, Cur)
            Cur = ValueSer(Value, Buf, Cur)
        end
        buffer.writeu16(Buf, Start, Len)
    
        return Cur
    end

    const function MapDes(Buf: buffer, Cur: number): ({ [K]: V }, number)
        const Len = buffer.readu16(Buf, Cur)
        const Map = {}
        Cur = Cur + 2
        const KeyDes = KeyDes
        const ValueDes = ValueDes
        for _ = 1, Len do
            local Key
            local Val
            Key, Cur = KeyDes(Buf, Cur)
            Val, Cur = ValueDes(Buf, Cur)
            Map[Key] = Val
        end
        return Map, Cur
    end

    MapNode[SER] = MapSer
    MapNode[DES] = MapDes

    return MapNode
end

-- Map8 (8 bits for length write, meaning max amount of elements in the map is 255)
const function Map8<K, V>(KeyNode: SerdesNode<K>, ValueNode: SerdesNode<V>): SerdesNode<{ [K]: V }>
    const Map8Node: SerdesNode<{ [K]: V }> = {}

    const KeySer = KeyNode[SER] :: Ser<K>
    const KeyDes = KeyNode[DES] :: Des<K>

    const ValueSer = ValueNode[SER] :: Ser<V>
    const ValueDes = ValueNode[DES] :: Des<V>

    const function Map8Ser(Map: { [K]: V }, Buf: buffer, Cur: number): number
        const Start = Cur
        local Len = 0
        Cur = Cur + 1
        const KeySer = KeySer
        const ValueSer = ValueSer
        for Key, Value in Map do
            Len += 1
            Cur = KeySer(Key, Buf, Cur)
            Cur = ValueSer(Value, Buf, Cur)
        end
        buffer.writeu8(Buf, Start, Len)
    
        return Cur
    end

    const function Map8Des(Buf: buffer, Cur: number): ({ [K]: V }, number)
        const Len = buffer.readu8(Buf, Cur)
        const Map = {}
        Cur = Cur + 1
        const KeyDes = KeyDes
        const ValueDes = ValueDes
        for _ = 1, Len do
            local Key
            local Val
            Key, Cur = KeyDes(Buf, Cur)
            Val, Cur = ValueDes(Buf, Cur)
            Map[Key] = Val
        end
        return Map, Cur
    end

    Map8Node[SER] = Map8Ser
    Map8Node[DES] = Map8Des

    return Map8Node
end

-- Map24 (24 bits for length write, meaning max amount of elements in the map is 16_777_215)
const function Map24<K, V>(KeyNode: SerdesNode<K>, ValueNode: SerdesNode<V>): SerdesNode<{ [K]: V }>
    const Map24Node: SerdesNode<{ [K]: V }> = {}

    const KeySer = KeyNode[SER] :: Ser<K>
    const KeyDes = KeyNode[DES] :: Des<K>

    const ValueSer = ValueNode[SER] :: Ser<V>
    const ValueDes = ValueNode[DES] :: Des<V>

    const function Map24Ser(Map: { [K]: V }, Buf: buffer, Cur: number): number
        const Start = Cur
        local Len = 0
        Cur = Cur + 3
        const KeySer = KeySer
        const ValueSer = ValueSer
        for Key, Value in Map do
            Len += 1
            Cur = KeySer(Key, Buf, Cur)
            Cur = ValueSer(Value, Buf, Cur)
        end
        buffer.writeu16(Buf, Start, bit32.band(Len, 0xFFFF))
        buffer.writeu8(Buf, Start + 2, bit32.band(bit32.rshift(Len, 16), 0xFF))
    
        return Cur
    end

    const function Map24Des(Buf: buffer, Cur: number): ({ [K]: V }, number)
        const b1: number = buffer.readu16(Buf, Cur)
        const b2: number = buffer.readu8(Buf, Cur + 2)
        const Len = bit32.bor(b1, bit32.lshift(b2, 16))
        const Map = {}
        Cur = Cur + 3
        const KeyDes = KeyDes
        const ValueDes = ValueDes
        for _ = 1, Len do
            local Key
            local Val
            Key, Cur = KeyDes(Buf, Cur)
            Val, Cur = ValueDes(Buf, Cur)
            Map[Key] = Val
        end
        return Map, Cur
    end

    Map24Node[SER] = Map24Ser
    Map24Node[DES] = Map24Des

    return Map24Node
end

-- ArrayFixed (fixed length)
const function ArrayFixed<T>(Node: SerdesNode<T>, Length: number): SerdesNode<{ T }>
    const ArrayFixedNode: SerdesNode<{ T }> = {}

    const Ser = Node[SER] :: Ser<T>
    const Des = Node[DES] :: Des<T>

    const function ArrayFixedSer(Array: { T }, Buf: buffer, Cur: number): number
        const Ser = Ser
        for _, Value in Array do
            Cur = Ser(Value, Buf, Cur)
        end
    
        return Cur
    end

    const function ArrayFixedDes(Buf: buffer, Cur: number): ({ T }, number)
        const Array = CreateTable<<T>>(Length)
        const Des = Des
        for i = 1, Length do
            Array[i], Cur = Des(Buf, Cur)
        end
        return Array, Cur
    end

    ArrayFixedNode[SER] = ArrayFixedSer
    ArrayFixedNode[DES] = ArrayFixedDes

    return ArrayFixedNode
end

-- MapFixed (fixed length)
const function MapFixed<K, V>(KeyNode: SerdesNode<K>, ValueNode: SerdesNode<V>, Length: number): SerdesNode<{ [K]: V }>
    const MapFixedNode: SerdesNode<{ [K]: V }> = {}

    const KeySer = KeyNode[SER] :: Ser<K>
    const KeyDes = KeyNode[DES] :: Des<K>

    const ValueSer = ValueNode[SER] :: Ser<V>
    const ValueDes = ValueNode[DES] :: Des<V>

    const function MapFixedSer(Map: { [K]: V }, Buf: buffer, Cur: number): number
        const KeySer = KeySer
        const ValueSer = ValueSer
        for Key, Value in Map do
            Cur = KeySer(Key, Buf, Cur)
            Cur = ValueSer(Value, Buf, Cur)
        end
    
        return Cur
    end

    const function MapFixedDes(Buf: buffer, Cur: number): ({ [K]: V }, number)
        const Map = {}
        const KeyDes = KeyDes
        const ValueDes = ValueDes
        for _ = 1, Length do
            local Key
            local Val
            Key, Cur = KeyDes(Buf, Cur)
            Val, Cur = ValueDes(Buf, Cur)
            Map[Key] = Val
        end
        return Map, Cur
    end

    MapFixedNode[SER] = MapFixedSer
    MapFixedNode[DES] = MapFixedDes

    return MapFixedNode
end

-- IEEE-754 Half Precision Float
const F16: SerdesNode<number> = {}
do
    const function F16Ser(Value: number, Buf: buffer, Cur: number): number
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

        buffer.writeu16(Buf, Cur, Packed)
        Cur = Cur + 2
    
        return Cur
    end

    const function F16Deser(Buf: buffer, Cur: number): (number, number)
        const Packed: number = buffer.readu16(Buf, Cur)
        Cur = Cur + 2
    
        const Exp16: number = bit32.band(bit32.rshift(Packed, 10), 0x1F)
        
        if Exp16 == 0 then
            return 0, Cur
        end
    
        const Sign: number = bit32.band(Packed, 0x8000)
        const Mant10: number = bit32.band(Packed, 0x3FF)
    
        const Result: number = math.ldexp(1 + Mant10 / 1024, Exp16 - 15)
        
        return (if Sign == 0 then Result else -Result), Cur
    end

    F16[SER] = F16Ser
    F16[DES] = F16Deser
end

-- Custom precision float
const F24: SerdesNode<number> = {}
do
    const function F24Ser(Value: number, Buf: buffer, Cur: number): number
        const Conv = FloatConverter

        buffer.writef32(Conv, 0, Value)
        const Bits: number = buffer.readu32(Conv, 0)
        
        -- drop the bottom 8 bits of precision to shrink it to 24 bits
        const Packed: number = bit32.rshift(Bits, 8)

        buffer.writeu16(Buf, Cur, bit32.band(Packed, 0xFFFF))
        Cur += 2
        buffer.writeu8(Buf, Cur, bit32.rshift(Packed, 16))
        
        Cur = Cur + 1
    
        return Cur
    end

    const function F24Deser(Buf: buffer, Cur: number): (number, number)
        const b1: number = buffer.readu16(Buf, Cur)
        Cur += 2
        const b2: number = buffer.readu8(Buf, Cur)
        Cur = Cur + 1

        const Packed: number = bit32.bor(b1, bit32.lshift(b2, 16))

        const Exp8: number = bit32.band(bit32.rshift(Packed, 15), 0xFF)
        
        if Exp8 == 0 then
            return 0, Cur
        end

        const Sign: number = bit32.band(Packed, 0x800000)
        if Exp8 == 255 then
            return (if Sign == 0 then MathHuge else NMathHuge), Cur
        end

        const Mant15: number = bit32.band(Packed, 0x7FFF)
        const Result: number = math.ldexp(1 + Mant15 / 32768, Exp8 - 127)

        return (if Sign == 0 then Result else -Result), Cur
    end

    F24[SER] = F24Ser
    F24[DES] = F24Deser
end

-- Unsigned 24-bit Integer
const U24: SerdesNode<number> = {}
do
    const function U24Ser(Value: number, Buf: buffer, Cur: number): number
        buffer.writeu16(Buf, Cur, bit32.band(Value, 0xFFFF))
        Cur += 2
        buffer.writeu8(Buf, Cur, bit32.band(bit32.rshift(Value, 16), 0xFF))
        
        Cur = Cur + 1
    
        return Cur
    end

    const function U24Deser(Buf: buffer, Cur: number): (number, number)
        const b1: number = buffer.readu16(Buf, Cur)
        Cur += 2
        const b2: number = buffer.readu8(Buf, Cur)
        Cur = Cur + 1

        return bit32.bor(b1, bit32.lshift(b2, 16)), Cur
    end

    U24[SER] = U24Ser
    U24[DES] = U24Deser
end

-- Signed 24-bit integer
const I24: SerdesNode<number> = {}
do
    const function I24Ser(Value: number, Buf: buffer, Cur: number): number
        -- exactly the same as U24
        buffer.writeu16(Buf, Cur, bit32.band(Value, 0xFFFF))
        Cur += 2
        buffer.writeu8(Buf, Cur, bit32.band(bit32.rshift(Value, 16), 0xFF))
        
        Cur = Cur + 1
    
        return Cur
    end

    const function I24Deser(Buf: buffer, Cur: number): (number, number)
        const b1: number = buffer.readu16(Buf, Cur)
        Cur += 2
        const b2: number = buffer.readu8(Buf, Cur)
        Cur = Cur + 1

        const Packed: number = bit32.bor(b1, bit32.lshift(b2, 16))
        return (if Packed >= 0x800000 then Packed - 0x1000000 else Packed), Cur
    end

    I24[SER] = I24Ser
    I24[DES] = I24Deser
end

const VectorF24: SerdesNode<Vector3> = {}
do
    const function VectorF24Ser(Value: Vector3, Buf: buffer, Cur: number): number
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

        Cur = Cur + 9
    
        return Cur
    end

    const function VectorF24Des(Buf: buffer, Cur: number): (Vector3, number)
        -- inlined f24des too, sorry :pray:
        local x = 0
        do
            const b1: number = buffer.readu16(Buf, Cur)
            const b2: number = buffer.readu8(Buf, Cur + 2)

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
            const b1: number = buffer.readu16(Buf, Cur + 3)
            const b2: number = buffer.readu8(Buf, Cur + 5)

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

        Cur = Cur + 9
        return Vector3.new(x, y, z), Cur
    end

    VectorF24[SER] = VectorF24Ser
    VectorF24[DES] = VectorF24Des
end

const VectorF16: SerdesNode<Vector3> = {}
do
    const function VectorF16Ser(Value: Vector3, Buf: buffer, Cur: number): number
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

        Cur = Cur + 6
    
        return Cur
    end

    const function VectorF16Des(Buf: buffer, Cur: number): (Vector3, number)

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

        Cur = Cur + 6
        return Vector3.new(x, y, z), Cur
    end

    VectorF16[SER] = VectorF16Ser
    VectorF16[DES] = VectorF16Des
end

const VectorU16: SerdesNode<Vector3> = {}
do
    const function VectorU16Ser(Value: Vector3, Buf: buffer, Cur: number): number

        buffer.writeu16(Buf, Cur, Value.X)
        buffer.writeu16(Buf, Cur + 2, Value.Y)
        buffer.writeu16(Buf, Cur + 4, Value.Z)
        Cur = Cur + 6
    
        return Cur
    end

    const function VectorU16Des(Buf: buffer, Cur: number): (Vector3, number)

        const x = buffer.readu16(Buf, Cur)
        const y = buffer.readu16(Buf, Cur + 2)
        const z = buffer.readu16(Buf, Cur + 4)
        Cur = Cur + 6

        return Vector3.new(x, y, z), Cur
    end

    VectorU16[SER] = VectorU16Ser
    VectorU16[DES] = VectorU16Des
end

const VectorI16: SerdesNode<Vector3> = {}
do
    const function VectorI16Ser(Value: Vector3, Buf: buffer, Cur: number): number

        buffer.writei16(Buf, Cur, Value.X)
        buffer.writei16(Buf, Cur + 2, Value.Y)
        buffer.writei16(Buf, Cur + 4, Value.Z)
        Cur = Cur + 6
    
        return Cur
    end

    const function VectorI16Des(Buf: buffer, Cur: number): (Vector3, number)

        const x = buffer.readi16(Buf, Cur)
        const y = buffer.readi16(Buf, Cur + 2)
        const z = buffer.readi16(Buf, Cur + 4)
        Cur = Cur + 6

        return Vector3.new(x, y, z), Cur
    end

    VectorI16[SER] = VectorI16Ser
    VectorI16[DES] = VectorI16Des
end

const VectorU8: SerdesNode<Vector3> = {}
do
    const function VectorU8Ser(Value: Vector3, Buf: buffer, Cur: number): number

        buffer.writeu8(Buf, Cur, Value.X)
        buffer.writeu8(Buf, Cur + 1, Value.Y)
        buffer.writeu8(Buf, Cur + 2, Value.Z)
        Cur = Cur + 3
    
        return Cur
    end

    const function VectorU8Des(Buf: buffer, Cur: number): (Vector3, number)

        const x = buffer.readu8(Buf, Cur)
        const y = buffer.readu8(Buf, Cur + 1)
        const z = buffer.readu8(Buf, Cur + 2)
        Cur = Cur + 3

        return Vector3.new(x, y, z), Cur
    end

    VectorU8[SER] = VectorU8Ser
    VectorU8[DES] = VectorU8Des
end

const Color3Node: SerdesNode<Color3> = {}
do
    const function Color3Ser(Value: Color3, Buf: buffer, Cur: number): number

        buffer.writeu8(Buf, Cur, Value.R * 255)
        buffer.writeu8(Buf, Cur + 1, Value.G * 255)
        buffer.writeu8(Buf, Cur + 2, Value.B * 255)
        Cur = Cur + 3
    
        return Cur
    end

    const function Color3Des(Buf: buffer, Cur: number): (Color3, number)

        const r = buffer.readu8(Buf, Cur)
        const g = buffer.readu8(Buf, Cur + 1)
        const b = buffer.readu8(Buf, Cur + 2)
        Cur = Cur + 3

        return NewColor3(r, g, b), Cur
    end

    Color3Node[SER] = Color3Ser
    Color3Node[DES] = Color3Des
end

const VectorI8: SerdesNode<Vector3> = {}
do
    const function VectorI8Ser(Value: Vector3, Buf: buffer, Cur: number): number

        buffer.writei8(Buf, Cur, Value.X)
        buffer.writei8(Buf, Cur + 1, Value.Y)
        buffer.writei8(Buf, Cur + 2, Value.Z)
        Cur = Cur + 3
    
        return Cur
    end

    const function VectorI8Des(Buf: buffer, Cur: number): (Vector3, number)

        const x = buffer.readi8(Buf, Cur)
        const y = buffer.readi8(Buf, Cur + 1)
        const z = buffer.readi8(Buf, Cur + 2)
        Cur = Cur + 3

        return Vector3.new(x, y, z), Cur
    end

    VectorI8[SER] = VectorI8Ser
    VectorI8[DES] = VectorI8Des
end

const VectorU24: SerdesNode<Vector3> = {}
do
    const function VectorU24Ser(Value: Vector3, Buf: buffer, Cur: number): number

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

        Cur = Cur + 9
    
        return Cur
    end

    const function VectorU24Des(Buf: buffer, Cur: number): (Vector3, number)

        local x = 0
        do
            const b1: number = buffer.readu16(Buf, Cur)
            const b2: number = buffer.readu8(Buf, Cur + 2)

            x = bit32.bor(b1, bit32.lshift(b2, 16))
        end

        local y = 0
        do
            const b1: number = buffer.readu16(Buf, Cur + 3)
            const b2: number = buffer.readu8(Buf, Cur + 5)

            y = bit32.bor(b1, bit32.lshift(b2, 16))
        end

        local z = 0
        do
            const b1: number = buffer.readu16(Buf, Cur + 6)
            const b2: number = buffer.readu8(Buf, Cur + 8)

            z = bit32.bor(b1, bit32.lshift(b2, 16))
        end

        Cur = Cur + 9
        return Vector3.new(x, y, z), Cur
    end

    VectorU24[SER] = VectorU24Ser
    VectorU24[DES] = VectorU24Des
end

const VectorI24: SerdesNode<Vector3> = {}
do
    const function VectorI24Ser(Value: Vector3, Buf: buffer, Cur: number): number

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

        Cur = Cur + 9
    
        return Cur
    end

    const function VectorI24Des(Buf: buffer, Cur: number): (Vector3, number)

        local x = 0
        do
            const b1: number = buffer.readu16(Buf, Cur)
            const b2: number = buffer.readu8(Buf, Cur + 2)

            const Packed: number = bit32.bor(b1, bit32.lshift(b2, 16))
            x = if Packed >= 0x800000 then Packed - 0x1000000 else Packed
        end

        local y = 0
        do
            const b1: number = buffer.readu16(Buf, Cur + 3)
            const b2: number = buffer.readu8(Buf, Cur + 5)

            const Packed: number = bit32.bor(b1, bit32.lshift(b2, 16))
            y = if Packed >= 0x800000 then Packed - 0x1000000 else Packed
        end

        local z = 0
        do
            const b1: number = buffer.readu16(Buf, Cur + 6)
            const b2: number = buffer.readu8(Buf, Cur + 8)

            const Packed: number = bit32.bor(b1, bit32.lshift(b2, 16))
            z = if Packed >= 0x800000 then Packed - 0x1000000 else Packed
        end

        Cur = Cur + 9
        return Vector3.new(x, y, z), Cur
    end

    VectorI24[SER] = VectorI24Ser
    VectorI24[DES] = VectorI24Des
end

const Vector2Node: SerdesNode<Vector2> = {}
do
    const function Vector2Ser(Value: Vector2, Buf: buffer, Cur: number): number
        buffer.writef32(Buf, Cur, Value.X)
        buffer.writef32(Buf, Cur + 4, Value.Y)
        Cur = Cur + 8
    
        return Cur
    end

    const function Vector2Des(Buf: buffer, Cur: number): (Vector2, number)
        const x = buffer.readf32(Buf, Cur)
        const y = buffer.readf32(Buf, Cur + 4)
        Cur = Cur + 8

        return Vector2.new(x, y), Cur
    end

    Vector2Node[SER] = Vector2Ser
    Vector2Node[DES] = Vector2Des
end

const Vector2F24: SerdesNode<Vector2> = {}
do
    const function Vector2F24Ser(Value: Vector2, Buf: buffer, Cur: number): number
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

        Cur = Cur + 6
    
        return Cur
    end

    const function Vector2F24Des(Buf: buffer, Cur: number): (Vector2, number)

        local x = 0
        do
            const b1: number = buffer.readu16(Buf, Cur)
            const b2: number = buffer.readu8(Buf, Cur + 2)
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
            const b1: number = buffer.readu16(Buf, Cur + 3)
            const b2: number = buffer.readu8(Buf, Cur + 5)
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

        Cur = Cur + 6
        return Vector2.new(x, y), Cur
    end

    Vector2F24[SER] = Vector2F24Ser
    Vector2F24[DES] = Vector2F24Des
end

const Vector2F16: SerdesNode<Vector2> = {}
do
    const function Vector2F16Ser(Value: Vector2, Buf: buffer, Cur: number): number
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

        Cur = Cur + 4
    
        return Cur
    end

    const function Vector2F16Des(Buf: buffer, Cur: number): (Vector2, number)

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

        Cur = Cur + 4
        return Vector2.new(x, y), Cur
    end

    Vector2F16[SER] = Vector2F16Ser
    Vector2F16[DES] = Vector2F16Des
end

const Vector2U16: SerdesNode<Vector2> = {}
do
    const function Vector2U16Ser(Value: Vector2, Buf: buffer, Cur: number): number
        buffer.writeu16(Buf, Cur, Value.X)
        buffer.writeu16(Buf, Cur + 2, Value.Y)
        Cur = Cur + 4
    
        return Cur
    end

    const function Vector2U16Des(Buf: buffer, Cur: number): (Vector2, number)
        const x = buffer.readu16(Buf, Cur)
        const y = buffer.readu16(Buf, Cur + 2)
        Cur = Cur + 4

        return Vector2.new(x, y), Cur
    end

    Vector2U16[SER] = Vector2U16Ser
    Vector2U16[DES] = Vector2U16Des
end

const Vector2I16: SerdesNode<Vector2> = {}
do
    const function Vector2I16Ser(Value: Vector2, Buf: buffer, Cur: number): number
        buffer.writei16(Buf, Cur, Value.X)
        buffer.writei16(Buf, Cur + 2, Value.Y)
        Cur = Cur + 4
    
        return Cur
    end

    const function Vector2I16Des(Buf: buffer, Cur: number): (Vector2, number)
        const x = buffer.readi16(Buf, Cur)
        const y = buffer.readi16(Buf, Cur + 2)
        Cur = Cur + 4

        return Vector2.new(x, y), Cur
    end

    Vector2I16[SER] = Vector2I16Ser
    Vector2I16[DES] = Vector2I16Des
end

const Vector2U8: SerdesNode<Vector2> = {}
do
    const function Vector2U8Ser(Value: Vector2, Buf: buffer, Cur: number): number
        buffer.writeu8(Buf, Cur, Value.X)
        buffer.writeu8(Buf, Cur + 1, Value.Y)
        Cur = Cur + 2
    
        return Cur
    end

    const function Vector2U8Des(Buf: buffer, Cur: number): (Vector2, number)
        const x = buffer.readu8(Buf, Cur)
        const y = buffer.readu8(Buf, Cur + 1)
        Cur = Cur + 2

        return Vector2.new(x, y), Cur
    end

    Vector2U8[SER] = Vector2U8Ser
    Vector2U8[DES] = Vector2U8Des
end

const Vector2I8: SerdesNode<Vector2> = {}
do
    const function Vector2I8Ser(Value: Vector2, Buf: buffer, Cur: number): number
        buffer.writei8(Buf, Cur, Value.X)
        buffer.writei8(Buf, Cur + 1, Value.Y)
        Cur = Cur + 2
    
        return Cur
    end

    const function Vector2I8Des(Buf: buffer, Cur: number): (Vector2, number)
        const x = buffer.readi8(Buf, Cur)
        const y = buffer.readi8(Buf, Cur + 1)
        Cur = Cur + 2

        return Vector2.new(x, y), Cur
    end

    Vector2I8[SER] = Vector2I8Ser
    Vector2I8[DES] = Vector2I8Des
end

const Vector2U24: SerdesNode<Vector2> = {}
do
    const function Vector2U24Ser(Value: Vector2, Buf: buffer, Cur: number): number

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

        Cur = Cur + 6
    
        return Cur
    end

    const function Vector2U24Des(Buf: buffer, Cur: number): (Vector2, number)

        local x = 0
        do
            const b1: number = buffer.readu16(Buf, Cur)
            const b2: number = buffer.readu8(Buf, Cur + 2)
            x = bit32.bor(b1, bit32.lshift(b2, 16))
        end

        local y = 0
        do
            const b1: number = buffer.readu16(Buf, Cur + 3)
            const b2: number = buffer.readu8(Buf, Cur + 5)
            y = bit32.bor(b1, bit32.lshift(b2, 16))
        end

        Cur = Cur + 6
        return Vector2.new(x, y), Cur
    end

    Vector2U24[SER] = Vector2U24Ser
    Vector2U24[DES] = Vector2U24Des
end

const Vector2I24: SerdesNode<Vector2> = {}
do
    const function Vector2I24Ser(Value: Vector2, Buf: buffer, Cur: number): number

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

        Cur = Cur + 6
    
        return Cur
    end

    const function Vector2I24Des(Buf: buffer, Cur: number): (Vector2, number)

        local x = 0
        do
            const b1: number = buffer.readu16(Buf, Cur)
            const b2: number = buffer.readu8(Buf, Cur + 2)
            const Packed: number = bit32.bor(b1, bit32.lshift(b2, 16))
            x = if Packed >= 0x800000 then Packed - 0x1000000 else Packed
        end

        local y = 0
        do
            const b1: number = buffer.readu16(Buf, Cur + 3)
            const b2: number = buffer.readu8(Buf, Cur + 5)
            const Packed: number = bit32.bor(b1, bit32.lshift(b2, 16))
            y = if Packed >= 0x800000 then Packed - 0x1000000 else Packed
        end

        Cur = Cur + 6
        return Vector2.new(x, y), Cur
    end

    Vector2I24[SER] = Vector2I24Ser
    Vector2I24[DES] = Vector2I24Des
end

const UDim2Node: SerdesNode<UDim2> = {}
do
    const function UDim2Ser(Value: UDim2, Buf: buffer, Cur: number): number
        buffer.writef32(Buf, Cur, Value.X.Scale)
        buffer.writef32(Buf, Cur + 4, Value.X.Offset)
        buffer.writef32(Buf, Cur + 8, Value.Y.Scale)
        buffer.writef32(Buf, Cur + 12, Value.Y.Offset)
        Cur = Cur + 16
    
        return Cur
    end

    const function UDim2Des(Buf: buffer, Cur: number): (UDim2, number)
        const xScale = buffer.readf32(Buf, Cur)
        const xOffset = buffer.readf32(Buf, Cur + 4)
        const yScale = buffer.readf32(Buf, Cur + 8)
        const yOffset = buffer.readf32(Buf, Cur + 12)
        Cur = Cur + 16

        return NewUDim2(xScale, xOffset, yScale, yOffset), Cur
    end

    UDim2Node[SER] = UDim2Ser
    UDim2Node[DES] = UDim2Des
end

const UDim2Scale: SerdesNode<UDim2> = {}
do
    const function UDim2ScaleSer(Value: UDim2, Buf: buffer, Cur: number): number
        buffer.writef32(Buf, Cur, Value.X.Scale)
        buffer.writef32(Buf, Cur + 4, Value.Y.Scale)
        Cur = Cur + 8
    
        return Cur
    end

    const function UDim2ScaleDes(Buf: buffer, Cur: number): (UDim2, number)
        const xScale = buffer.readf32(Buf, Cur)
        const yScale = buffer.readf32(Buf, Cur + 4)
        Cur = Cur + 8

        return FromUDim2Scale(xScale, yScale), Cur
    end

    UDim2Scale[SER] = UDim2ScaleSer
    UDim2Scale[DES] = UDim2ScaleDes
end

const UDim2Offset: SerdesNode<UDim2> = {}
do
    const function UDim2OffsetSer(Value: UDim2, Buf: buffer, Cur: number): number
        buffer.writef32(Buf, Cur, Value.X.Offset)
        buffer.writef32(Buf, Cur + 4, Value.Y.Offset)
        Cur = Cur + 8
    
        return Cur
    end

    const function UDim2OffsetDes(Buf: buffer, Cur: number): (UDim2, number)
        const xOffset = buffer.readf32(Buf, Cur)
        const yOffset = buffer.readf32(Buf, Cur + 4)
        Cur = Cur + 8

        return FromUDim2Offset(xOffset, yOffset), Cur
    end

    UDim2Offset[SER] = UDim2OffsetSer
    UDim2Offset[DES] = UDim2OffsetDes
end

const UDim2OffsetI16: SerdesNode<UDim2> = {}
do
    const function UDim2OffsetI16Ser(Value: UDim2, Buf: buffer, Cur: number): number
        buffer.writei16(Buf, Cur, Value.X.Offset)
        buffer.writei16(Buf, Cur + 2, Value.Y.Offset)
        Cur = Cur + 4
    
        return Cur
    end

    const function UDim2OffsetI16Des(Buf: buffer, Cur: number): (UDim2, number)
        const xOffset = buffer.readi16(Buf, Cur)
        const yOffset = buffer.readi16(Buf, Cur + 2)
        Cur = Cur + 4

        return FromUDim2Offset(xOffset, yOffset), Cur
    end

    UDim2OffsetI16[SER] = UDim2OffsetI16Ser
    UDim2OffsetI16[DES] = UDim2OffsetI16Des
end

const UDim2ScaleF24: SerdesNode<UDim2> = {}
do
    const function UDim2ScaleF24Ser(Value: UDim2, Buf: buffer, Cur: number): number
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

        Cur = Cur + 6
    
        return Cur
    end

    const function UDim2ScaleF24Des(Buf: buffer, Cur: number): (UDim2, number)

        local xScale = 0
        do
            const b1: number = buffer.readu16(Buf, Cur)
            const b2: number = buffer.readu8(Buf, Cur + 2)
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
            const b1: number = buffer.readu16(Buf, Cur + 3)
            const b2: number = buffer.readu8(Buf, Cur + 5)
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

        Cur = Cur + 6
        return FromUDim2Scale(xScale, yScale), Cur
    end

    UDim2ScaleF24[SER] = UDim2ScaleF24Ser
    UDim2ScaleF24[DES] = UDim2ScaleF24Des
end

const Bool: SerdesNode<boolean> = {}
do
    const function BoolSer(Value: boolean, Buf: buffer, Cur: number): number
        buffer.writeu8(Buf, Cur, Value and 1 or 0)
        Cur = Cur + 1
    
        return Cur
    end

    const function BoolDes(Buf: buffer, Cur: number): (boolean, number)
        const Value = buffer.readu8(Buf, Cur)
        Cur = Cur + 1
        return Value == 1, Cur
    end

    Bool[SER] = BoolSer
    Bool[DES] = BoolDes
end

const BoolPacked: SerdesNode<{ boolean }> = {}
do
    const function BoolPackedSer(Value: { boolean }, Buf: buffer, Cur: number): number
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

        buffer.writeu8(Buf, Cur, Write)
        Cur = Cur + 1
    
        return Cur
    end

    const function BoolPackedDes(Buf: buffer, Cur: number): ({ boolean }, number)
        const Byte = buffer.readu8(Buf, Cur)
        Cur = Cur + 1

        return { 
			bit32.btest(Byte, 1),
			bit32.btest(Byte, 2),
			bit32.btest(Byte, 4),
			bit32.btest(Byte, 8),
			bit32.btest(Byte, 16),
			bit32.btest(Byte, 32),
			bit32.btest(Byte, 64),
			bit32.btest(Byte, 128), 
        }, Cur
    end

    BoolPacked[SER] = BoolPackedSer
    BoolPacked[DES] = BoolPackedDes
end

-- Buffer (2 bytes for length, meaning max amount of bytes in the buffer is 65535)
const Buffer: SerdesNode<buffer> = {}
do
    const function BufferSer(Value: buffer, Buf: buffer, Cur: number): number
        const Len = BufferLen(Value)
        buffer.writeu16(Buf, Cur, Len)
        Cur += 2
        CopyBuffer(Buf, Cur, Value, 0, Len)
        Cur = Cur + Len
    
        return Cur
    end

    const function BufferDes(Buf: buffer, Cur: number): (buffer, number)
        const Length = buffer.readu16(Buf, Cur)
        Cur += 2
        const Value = CreateBuffer(Length)
        CopyBuffer(Value, 0, Buf, Cur, Length)
        Cur = Cur + Length
        return Value, Cur
    end

    Buffer[SER] = BufferSer
    Buffer[DES] = BufferDes
end

-- Buffer8 (1 byte for length, meaning max amount of bytes in the buffer is 255)
const Buffer8: SerdesNode<buffer> = {}
do
    const function Buffer8Ser(Value: buffer, Buf: buffer, Cur: number): number
        const Len = BufferLen(Value)
        buffer.writeu8(Buf, Cur, Len)
        Cur += 1
        CopyBuffer(Buf, Cur, Value, 0, Len)
        Cur = Cur + Len
    
        return Cur
    end

    const function Buffer8Des(Buf: buffer, Cur: number): (buffer, number)
        const Length = buffer.readu8(Buf, Cur)
        Cur += 1
        const Value = CreateBuffer(Length)
        CopyBuffer(Value, 0, Buf, Cur, Length)
        Cur = Cur + Length
        return Value, Cur
    end

    Buffer8[SER] = Buffer8Ser
    Buffer8[DES] = Buffer8Des
end

-- Buffer24 (3 bytes for length, meaning max amount of bytes in the buffer is 16_777_215)
const Buffer24: SerdesNode<buffer> = {}
do
    const function Buffer24Ser(Value: buffer, Buf: buffer, Cur: number): number
        const Len = BufferLen(Value)
        buffer.writeu16(Buf, Cur, bit32.band(Len, 0xFFFF))
        buffer.writeu8(Buf, Cur + 2, bit32.band(bit32.rshift(Len, 16), 0xFF))
        CopyBuffer(Buf, Cur + 3, Value, 0, Len)
        Cur = Cur + 3 + Len
    
        return Cur
    end

    const function Buffer24Des(Buf: buffer, Cur: number): (buffer, number)
        const b1: number = buffer.readu16(Buf, Cur)
        const b2: number = buffer.readu8(Buf, Cur + 2)

        const Length = bit32.bor(b1, bit32.lshift(b2, 16))
        const b = CreateBuffer(Length)
        CopyBuffer(b, 0, Buf, Cur + 3, Length)
        Cur = Cur + 3 + Length
        return b, Cur
    end

    Buffer24[SER] = Buffer24Ser
    Buffer24[DES] = Buffer24Des
end

-- BufferFixed (fixed length)
const function BufferFixed(Length: number): SerdesNode<buffer>
    const BufferFixedNode: SerdesNode<buffer> = {}

    const function BufferFixedSer(Value: buffer, Buf: buffer, Cur: number): number
        CopyBuffer(Buf, Cur, Value, 0, Length)
        Cur = Cur + Length
    
        return Cur
    end

    const function BufferFixedDes(Buf: buffer, Cur: number): (buffer, number)
        const Value = CreateBuffer(Length)
        CopyBuffer(Value, 0, Buf, Cur, Length)
        Cur = Cur + Length
        return Value, Cur
    end

    BufferFixedNode[SER] = BufferFixedSer
    BufferFixedNode[DES] = BufferFixedDes

    return BufferFixedNode
end

const function Optional<T>(Node: SerdesNode<T>): SerdesNode<T?>
    const OptionalNode: SerdesNode<T?> = {}

    const function OptionalSer(Value: T?, Buf: buffer, Cur: number): number
        const Exists = Value ~= nil
        buffer.writeu8(Buf, Cur, Exists and 1 or 0)
        Cur = Cur + 1
        if Exists then
            const Ser = Node[SER] :: Ser<T>
            Cur = Ser(Value :: T, Buf, Cur)
        end
    
        return Cur
    end

    const function OptionalDes(Buf: buffer, Cur: number): (T?, number)
        const Exists = buffer.readu8(Buf, Cur)
        Cur = Cur + 1
        if Exists == 1 then
            const Des = Node[DES] :: Des<T>
            local Result
            Result, Cur = Des(Buf, Cur)
            return Result, Cur
        end

        return nil, Cur
    end

    OptionalNode[SER] = OptionalSer
    OptionalNode[DES] = OptionalDes

    return OptionalNode
end

-- Instance (2 bytes for id write, if your game has more than 65535 instances at once, consider using Instance24)
const InstanceNode: SerdesNode<Instance> = {}
do
    const function InstanceSer(Value: Instance, Buf: buffer, Cur: number): number
        const Id = InstanceMap[Value]
        if Id then
            buffer.writeu16(Buf, Cur, Id)
            Cur = Cur + 2
        else
            error(`Instance {Value:GetFullName()} not found in InstanceMap, make sure INSTANCE_SERIALIZATION_ENABLED is set to true`)
        end
    
        return Cur
    end

    const function InstanceDes(Buf: buffer, Cur: number): (Instance, number)
        const Id = buffer.readu16(Buf, Cur)
        Cur = Cur + 2
        const Value = IdMap[Id]
        if not Value then
            error(`Instance not found by id {Id}, make sure INSTANCE_SERIALIZATION_ENABLED is set to true and the Instance is reachable by this context.`)
        end

        return Value, Cur
    end

    InstanceNode[SER] = InstanceSer
    InstanceNode[DES] = InstanceDes
end

-- Instance24 (3 bytes for id write, max amount of instances at a time is 16_777_215)
const Instance24: SerdesNode<Instance> = {}
do
    const function Instance24Ser(Value: Instance, Buf: buffer, Cur: number): number
        const Id = InstanceMap[Value]
        if Id then
            buffer.writeu16(Buf, Cur, bit32.band(Id, 0xFFFF))
            Cur += 2
            buffer.writeu8(Buf, Cur, bit32.band(bit32.rshift(Id, 16), 0xFF))
            Cur = Cur + 1
        else
            error(`Instance {Value:GetFullName()} not found in InstanceMap, make sure INSTANCE_SERIALIZATION_ENABLED is set to true`)
        end
    
        return Cur
    end

    const function Instance24Des(Buf: buffer, Cur: number): (Instance, number)
        const b1: number = buffer.readu16(Buf, Cur)
        Cur += 2
        const b2: number = buffer.readu8(Buf, Cur)
        Cur = Cur + 1

        const Id = bit32.bor(b1, bit32.lshift(b2, 16))
        const Value = IdMap[Id]
        if not Value then
            error(`Instance not found by id {Id}, make sure INSTANCE_SERIALIZATION_ENABLED is set to true and the Instance is reachable by this context.`)
        end

        return Value, Cur
    end

    Instance24[SER] = Instance24Ser
    Instance24[DES] = Instance24Des
end

const CFrameNode: SerdesNode<CFrame> = {}
do
    const function CFrameSer(Value: CFrame, Buf: buffer, Cur: number): number
        const 
        x: number, y: number, z: number, 
        R0: number, R01: number, R02: number, 
        R10: number, R11: number, R12: number, 
        R20: number, R21: number, R22: number 
        = Value:GetComponents()


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
        Cur = Cur + 48
    
        return Cur
    end
    
    const function CFrameDes(Buf: buffer, Cur: number): (CFrame, number)

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
        Cur = Cur + 48

        return NewCFrame(x, y, z, R0, R01, R02, R10, R11, R12, R20, R21, R22), Cur
    end

    CFrameNode[SER] = CFrameSer
    CFrameNode[DES] = CFrameDes
end

const CFrameQuant8: SerdesNode<CFrame> = {}
do
    const function CFrameQuant8Ser(Value: CFrame, Buf: buffer, Cur: number): number
        const x, y, z = Value.X, Value.Y, Value.Z


        buffer.writef32(Buf, Cur, x)
        buffer.writef32(Buf, Cur + 4, y)
        buffer.writef32(Buf, Cur + 8, z)
        const rx, ry, rz = Value:ToOrientation()

        const normalYaw = math.min((ry + Pi) / DoublePi, 1)
        const normalPitch = math.min((rx + HalfPi) / Pi, 1)
        const normalRoll = math.min((rz + Pi) / DoublePi, 1)

        buffer.writeu8(Buf, Cur + 12, math.round(normalYaw * 255))
        buffer.writeu8(Buf, Cur + 13, math.round(normalPitch * 255))
        buffer.writeu8(Buf, Cur + 14, math.round(normalRoll * 255))

        return Cur + 15
    end

    const function CFrameQuant8Des(Buf: buffer, Cur: number): (CFrame, number)

        const x = buffer.readf32(Buf, Cur)
        const y = buffer.readf32(Buf, Cur + 4)
        const z = buffer.readf32(Buf, Cur + 8)
        const Yaw = buffer.readu8(Buf, Cur + 12)
        const Pitch = buffer.readu8(Buf, Cur + 13)
        const Roll = buffer.readu8(Buf, Cur + 14)

        const ry = (Yaw / 255) * DoublePi - Pi
	    const rx = (Pitch / 255) * Pi - HalfPi
	    const rz = (Roll / 255) * DoublePi - Pi

        return NewCFrame(x, y, z) * NewCFrameFromOrientation(rx, ry, rz), Cur + 15
    end

    CFrameQuant8[SER] = CFrameQuant8Ser
    CFrameQuant8[DES] = CFrameQuant8Des
end

const CFrameQuant8F16: SerdesNode<CFrame> = {}
do
    const function CFrameQuant8F16Ser(Value: CFrame, Buf: buffer, Cur: number): number
        const x, y, z = Value.X, Value.Y, Value.Z

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

            buffer.writeu16(Buf, Cur + 2, Packed)
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

            buffer.writeu16(Buf, Cur + 4, Packed)
        end
        const rx, ry, rz = Value:ToOrientation()

        const normalYaw = math.min((ry + Pi) / DoublePi, 1)
        const normalPitch = math.min((rx + HalfPi) / Pi, 1)
        const normalRoll = math.min((rz + Pi) / DoublePi, 1)

        buffer.writeu8(Buf, Cur + 6, math.round(normalYaw * 255))
        buffer.writeu8(Buf, Cur + 7, math.round(normalPitch * 255))
        buffer.writeu8(Buf, Cur + 8, math.round(normalRoll * 255))

        return Cur + 9
    end

    const function CFrameQuant8F16Des(Buf: buffer, Cur: number): (CFrame, number)

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
        const Yaw = buffer.readu8(Buf, Cur + 6)
        const Pitch = buffer.readu8(Buf, Cur + 7)
        const Roll = buffer.readu8(Buf, Cur + 8)

        const ry = (Yaw / 255) * DoublePi - Pi
	    const rx = (Pitch / 255) * Pi - HalfPi
	    const rz = (Roll / 255) * DoublePi - Pi

        return NewCFrame(x, y, z) * NewCFrameFromOrientation(rx, ry, rz), Cur + 9
    end

    CFrameQuant8F16[SER] = CFrameQuant8F16Ser
    CFrameQuant8F16[DES] = CFrameQuant8F16Des
end

const CFrameQuant: SerdesNode<CFrame> = {}
do
    const function CFrameQuantSer(Value: CFrame, Buf: buffer, Cur: number): number
        const x, y, z = Value.X, Value.Y, Value.Z


        buffer.writef32(Buf, Cur, x)
        buffer.writef32(Buf, Cur + 4, y)
        buffer.writef32(Buf, Cur + 8, z)
        const rx, ry, rz = Value:ToOrientation()

        const normalYaw = math.min((ry + Pi) / DoublePi, 1)
        const normalPitch = math.min((rx + HalfPi) / Pi, 1)
        const normalRoll = math.min((rz + Pi) / DoublePi, 1)

        buffer.writeu16(Buf, Cur + 12, math.round(normalYaw * 65535))
        buffer.writeu16(Buf, Cur + 14, math.round(normalPitch * 65535))
        buffer.writeu16(Buf, Cur + 16, math.round(normalRoll * 65535))

        return Cur + 18
    end

    const function CFrameQuantDes(Buf: buffer, Cur: number): (CFrame, number)

        const x = buffer.readf32(Buf, Cur)
        const y = buffer.readf32(Buf, Cur + 4)
        const z = buffer.readf32(Buf, Cur + 8)
        const Yaw = buffer.readu16(Buf, Cur + 12)
        const Pitch = buffer.readu16(Buf, Cur + 14)
        const Roll = buffer.readu16(Buf, Cur + 16)

        const ry = (Yaw / 65535) * DoublePi - Pi
	    const rx = (Pitch / 65535) * Pi - HalfPi
	    const rz = (Roll / 65535) * DoublePi - Pi

        return NewCFrame(x, y, z) * NewCFrameFromOrientation(rx, ry, rz), Cur + 18
    end

    CFrameQuant[SER] = CFrameQuantSer
    CFrameQuant[DES] = CFrameQuantDes
end

const CFrameQuantF16: SerdesNode<CFrame> = {}
do
    const function CFrameQuantF16Ser(Value: CFrame, Buf: buffer, Cur: number): number
        const x, y, z = Value.X, Value.Y, Value.Z

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

            buffer.writeu16(Buf, Cur + 2, Packed)
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

            buffer.writeu16(Buf, Cur + 4, Packed)
        end
        const rx, ry, rz = Value:ToOrientation()

        const normalYaw = math.min((ry + Pi) / DoublePi, 1)
        const normalPitch = math.min((rx + HalfPi) / Pi, 1)
        const normalRoll = math.min((rz + Pi) / DoublePi, 1)

        buffer.writeu16(Buf, Cur + 6, math.round(normalYaw * 65535))
        buffer.writeu16(Buf, Cur + 8, math.round(normalPitch * 65535))
        buffer.writeu16(Buf, Cur + 10, math.round(normalRoll * 65535))

        return Cur + 12
    end

    const function CFrameQuantF16Des(Buf: buffer, Cur: number): (CFrame, number)

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
        const Yaw = buffer.readu16(Buf, Cur + 6)
        const Pitch = buffer.readu16(Buf, Cur + 8)
        const Roll = buffer.readu16(Buf, Cur + 10)

        const ry = (Yaw / 65535) * DoublePi - Pi
	    const rx = (Pitch / 65535) * Pi - HalfPi
	    const rz = (Roll / 65535) * DoublePi - Pi

        return NewCFrame(x, y, z) * NewCFrameFromOrientation(rx, ry, rz), Cur + 12
    end

    CFrameQuantF16[SER] = CFrameQuantF16Ser
    CFrameQuantF16[DES] = CFrameQuantF16Des
end

const QCFrame: SerdesNode<CFrame> = {}
do  
    const function QCFrameSer(Value: CFrame, Buf: buffer, Cur: number): number
        const Pos = Value.Position
        const Axis, Angle = Value:ToAxisAngle()
    
        const HalfAngle = Angle * 0.5
        const s = math.sin(HalfAngle)
    
        const qx = Axis.X * s
        const qy = Axis.Y * s
        const qz = Axis.Z * s
        const qw = math.cos(HalfAngle)
    
    
        buffer.writef32(Buf, Cur, Pos.X)
        buffer.writef32(Buf, Cur + 4, Pos.Y)
        buffer.writef32(Buf, Cur + 8, Pos.Z)
        buffer.writef32(Buf, Cur + 12, qx)
        buffer.writef32(Buf, Cur + 16, qy)
        buffer.writef32(Buf, Cur + 20, qz)
        buffer.writef32(Buf, Cur + 24, qw)
    
        Cur = Cur + 28
    
        return Cur
    end
    
    const function QCFrameDes(Buf: buffer, Cur: number): (CFrame, number)

        const x = buffer.readf32(Buf, Cur)
        const y = buffer.readf32(Buf, Cur + 4)
        const z = buffer.readf32(Buf, Cur + 8)
        const qx = buffer.readf32(Buf, Cur + 12)
        const qy = buffer.readf32(Buf, Cur + 16)
        const qz = buffer.readf32(Buf, Cur + 20)
        const qw = buffer.readf32(Buf, Cur + 24)
        Cur = Cur + 28

        return NewCFrame(x, y, z, qx, qy, qz, qw), Cur
    end

    QCFrame[SER] = QCFrameSer
    QCFrame[DES] = QCFrameDes
end

const CFrameF24: SerdesNode<CFrame> = {}
do
    const function CFrameF24Ser(Value: CFrame, Buf: buffer, Cur: number): number
        const
        x: number, y: number, z: number,
        R0: number, R01: number, R02: number,
        R10: number, R11: number, R12: number,
        R20: number, R21: number, R22: number
        = Value:GetComponents()

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
    
        return Cur
    end

    const function CFrameF24Des(Buf: buffer, Cur: number): (CFrame, number)

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
        return NewCFrame(x, y, z, R0, R01, R02, R10, R11, R12, R20, R21, R22), Cur
    end

    CFrameF24[SER] = CFrameF24Ser
    CFrameF24[DES] = CFrameF24Des
end

const CFrameF16: SerdesNode<CFrame> = {}
do
    const function CFrameF16Ser(Value: CFrame, Buf: buffer, Cur: number): number
        const
        x: number, y: number, z: number,
        R0: number, R01: number, R02: number,
        R10: number, R11: number, R12: number,
        R20: number, R21: number, R22: number
        = Value:GetComponents()

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
    
        return Cur
    end

    const function CFrameF16Des(Buf: buffer, Cur: number): (CFrame, number)

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
        return NewCFrame(x, y, z, R0, R01, R02, R10, R11, R12, R20, R21, R22), Cur
    end

    CFrameF16[SER] = CFrameF16Ser
    CFrameF16[DES] = CFrameF16Des
end

const QCFrameF24: SerdesNode<CFrame> = {}
do
    const function QCFrameF24Ser(Value: CFrame, Buf: buffer, Cur: number): number
        const Pos = Value.Position
        const Axis, Angle = Value:ToAxisAngle()
        const HalfAngle = Angle * 0.5
        const s = math.sin(HalfAngle)
        const qx = Axis.X * s
        const qy = Axis.Y * s
        const qz = Axis.Z * s
        const qw = math.cos(HalfAngle)
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
    
        return Cur
    end

    const function QCFrameF24Des(Buf: buffer, Cur: number): (CFrame, number)

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
        return NewCFrame(x, y, z, qx, qy, qz, qw), Cur
    end

    QCFrameF24[SER] = QCFrameF24Ser
    QCFrameF24[DES] = QCFrameF24Des
end

const QCFrameF16: SerdesNode<CFrame> = {}
do
    const function QCFrameF16Ser(Value: CFrame, Buf: buffer, Cur: number): number
        const Pos = Value.Position
        const Axis, Angle = Value:ToAxisAngle()
        const HalfAngle = Angle * 0.5
        const s = math.sin(HalfAngle)
        const qx = Axis.X * s
        const qy = Axis.Y * s
        const qz = Axis.Z * s
        const qw = math.cos(HalfAngle)
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
    
        return Cur
    end

    const function QCFrameF16Des(Buf: buffer, Cur: number): (CFrame, number)

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
        return NewCFrame(x, y, z, qx, qy, qz, qw), Cur
    end

    QCFrameF16[SER] = QCFrameF16Ser
    QCFrameF16[DES] = QCFrameF16Des
end

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

    const function SerInstanceSer(Value: Instance, Buf: buffer, Cur: number): number
        const Keys = Keys
        const Writes = Writes
        for i, Key in Keys do
            Cur = Writes[i]((Value :: any)[Key], Buf, Cur)
        end
    
        return Cur
    end

    const function SerInstanceDes(Buf: buffer, Cur: number): (GetInstanceType<T, Instances, Instance>, number)
        const Inst = NewInstance(ClassName) :: any
        const Keys = Keys
        const Reads = Reads
        for i, Key in Keys do
            Inst[Key], Cur = Reads[i](Buf, Cur)
        end

        return Inst, Cur
    end

    SerInstanceNode[SER] = SerInstanceSer
    SerInstanceNode[DES] = SerInstanceDes
    return SerInstanceNode
end

const function EnumNode<T>(EnumType: T & Enum): SerdesNode<GetEnumItem<T>>
    const Node: SerdesNode<GetEnumItem<T>> = {}
    
    const function EnumSer(Value: EnumItem & GetEnumItem<T>, Buf: buffer, Cur: number): number
        buffer.writeu16(Buf, Cur, Value.Value)
        Cur = Cur + 2
    
        return Cur
    end

    const function EnumDes(Buf: buffer, Cur: number): (GetEnumItem<T>, number)
        const Value = buffer.readu16(Buf, Cur)
        Cur = Cur + 2
        return EnumType:FromValue(Value), Cur
    end

    Node[SER] = EnumSer
    Node[DES] = EnumDes

    return Node
end

const function Enum8<T>(EnumType: T & Enum): SerdesNode<GetEnumItem<T>>
    const Node: SerdesNode<GetEnumItem<T>> = {}
    
    const function Enum8Ser(Value: EnumItem & GetEnumItem<T>, Buf: buffer, Cur: number): number
        buffer.writeu8(Buf, Cur, Value.Value)
        Cur = Cur + 1
    
        return Cur
    end

    const function Enum8Des(Buf: buffer, Cur: number): (GetEnumItem<T>, number)
        const Value = buffer.readu8(Buf, Cur)
        Cur = Cur + 1
        return EnumType:FromValue(Value), Cur
    end

    Node[SER] = Enum8Ser
    Node[DES] = Enum8Des

    return Node
end

const function UDim2Quant(MinScale: number, MaxScale: number)
    const UDim2QuantNode: SerdesNode<UDim2> = {}
    const QuantizedScaleRange = MaxScale - MinScale
    const QuantizedScale = QuantizedScaleRange / 65535

    const function UDim2QuantSer(Value: UDim2, Buf: buffer, Cur: number): number
        const X, Y = Value.X, Value.Y
        const MinScale = MinScale
        const QuantizedScale = QuantizedScale
        buffer.writeu16(Buf, Cur, (X.Scale - MinScale) // QuantizedScale)
        buffer.writeu16(Buf, Cur + 2, (Y.Scale - MinScale) // QuantizedScale)
        return Cur + 4
    end

    const function UDim2QuantDes(Buf: buffer, Cur: number): (UDim2, number)
        const MinScale = MinScale
        const QuantizedScale = QuantizedScale
        const X = MinScale + buffer.readu16(Buf, Cur) * QuantizedScale
        const Y = MinScale + buffer.readu16(Buf, Cur + 2) * QuantizedScale
        return FromUDim2Scale(X, Y), Cur + 4
    end

    UDim2QuantNode[SER] = UDim2QuantSer
    UDim2QuantNode[DES] = UDim2QuantDes
    return UDim2QuantNode
end

Types.U8 = U8
Types.I8 = I8
Types.U16 = U16
Types.I16 = I16
Types.U32 = U32
Types.I32 = I32
Types.F32 = F32
Types.U40 = U40
Types.I40 = I40
Types.U48 = U48
Types.I48 = I48
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
Types.UDim2Quant = UDim2Quant
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
Types.CFrameQuant = CFrameQuant
Types.CFrameQuant8 = CFrameQuant8
Types.CFrameQuantF16 = CFrameQuantF16
Types.CFrameQuant8F16 = CFrameQuant8F16
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
	const Ser = Schema[SER] :: Ser<T>
    const WBuf = WriteBuffer
	const Cur = Ser(Value, WBuf, 0)
	const Buf = CreateBuffer(Cur)
	CopyBuffer(Buf, 0, WBuf, 0, Cur)
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
	const Ser = Schema[SER] :: Ser<T>
    const WBuf = WriteBuffer
	const Cur = Ser(Value, WBuf, 0)
	const Buf = CreateBuffer(Cur + Offset)
	CopyBuffer(Buf, Offset, WBuf, 0, Cur)
	return Buf
end

--- Deserializes a buffer from byte zero using the supplied schema.
---
--- The schema must match the schema and node choices used by the writer.
--- @tag Core
--- @param Schema SerdesNode<T> -- Schema that defines the wire representation.
--- @param Buffer buffer -- Buffer containing the encoded value.
--- @return T, number (cursor)
function VoidSentryUltimate.Deserialize<T>(Schema: SerdesNode<T>, Buffer: buffer): (T, number)
	const Des = Schema[DES] :: Des<T>
	return Des(Buffer, 0)
end

--- Writes a serialized value directly into an existing buffer.
---
--- The destination must already be large enough. `Offset` defaults to zero.
--- Returns the byte offset after the written payload.
--- @tag Core
--- @param Schema SerdesNode<T> -- Schema that defines the wire representation.
--- @param Value T -- Value to serialize.
--- @param Buffer buffer -- Existing destination buffer.
--- @param Offset number? -- Byte offset at which writing begins. Defaults to 0.
--- @return number (cursor)
function VoidSentryUltimate.Push<T>(Schema: SerdesNode<T>, Value: T, Buffer: buffer, Offset: number?): number
    const Ser = Schema[SER] :: Ser<T>
    return Ser(Value, Buffer, Offset or 0)
end

--- Deserializes a value beginning at a byte offset in a buffer.
--- @tag Core
--- @param Schema SerdesNode<T> -- Schema that defines the wire representation.
--- @param Buffer buffer -- Buffer containing the encoded value.
--- @param Offset number -- Byte offset at which reading begins.
--- @return T, number (cursor)
function VoidSentryUltimate.DeserializeWithOffset<T>(Schema: SerdesNode<T>, Buffer: buffer, Offset: number): (T, number)
	const Des = Schema[DES] :: Des<T>
	return Des(Buffer, Offset)
end

--- Creates a schema object from a map of field names to type nodes.
---
--- Field names are collected and sorted lexicographically. The returned object
--- exposes full-struct and delta helpers. Maximum 255 fields.
--- @within VoidSentryUltimate
--- @tag Core
--- @param Tbl T -- Map of field name to `SerdesNode`.
--- @return Schema
function VoidSentryUltimate.Schema<T>(Tbl: { [string]: SerdesNode<any> } & T): Schema<GetTypeFromTypeNodes<T>>
    const Object = {}

    const Keys = {}
    local Idx = 0
    for Key in Tbl :: { [string]: SerdesNode<any> } do
        Idx += 1
        Keys[Idx] = Key
    end
    if Idx > 255 then
        error("Schema cannot have more than 255 fields, provided fields: " .. Idx)
    end
    table.sort(Keys)

    const Writes = CreateTable<<Ser<any>>>(Idx)
    const Reads = CreateTable<<Des<any>>>(Idx)
    const KeyIndex: { [string]: number } = {}

    for i, Key in Keys do
        const Node = Tbl[Key]
        const Ser, Des = Node[SER] :: Ser<any>, Node[DES] :: Des<any>
        Writes[i] = Ser
        Reads[i] = Des
        KeyIndex[Key] = i
    end

    function Object.Serialize(Data: { [string]: any } & GetTypeFromTypeNodes<T>): buffer
        const Zero = 0
        local Cur = Zero
        const Writes = Writes
        const Keys = Keys
        const WBuf = WriteBuffer
        for i, Key in Keys do
            Cur = Writes[i](Data[Key], WBuf, Cur)
        end
        const Buf = CreateBuffer(Cur)
        CopyBuffer(Buf, Zero, WBuf, Zero, Cur)
        return Buf
    end

    function Object.SerializeWithOffset(Data: { [string]: any } & GetTypeFromTypeNodes<T>, Offset: number): buffer
        local Cur = 0
        const Writes = Writes
        const Keys = Keys
        const WBuf = WriteBuffer
        for i, Key in Keys do
            Cur = Writes[i](Data[Key], WBuf, Cur)
        end
        const Buf = CreateBuffer(Offset + Cur)
        CopyBuffer(Buf, Offset, WBuf, 0, Cur)
        return Buf
    end

    function Object.Push(Data: { [string]: any } & GetTypeFromTypeNodes<T>, Buffer: buffer, Offset: number?): number
        local Cur = Offset or 0
        const Keys = Keys
        const Writes = Writes
        for i, Key in Keys do
            Cur = Writes[i](Data[Key], Buffer, Cur)
        end
        return Cur
    end

    function Object.Deserialize(Buffer: buffer): (GetTypeFromTypeNodes<T>, number)
        local Cur = 0
        const Result = {}
        const Keys = Keys
        const Reads = Reads
        for i, Key in Keys do
            Result[Key], Cur = Reads[i](Buffer, Cur)
        end
        return Result :: GetTypeFromTypeNodes<T>, Cur
    end

    function Object.DeserializeWithOffset(Buffer: buffer, Offset: number): (GetTypeFromTypeNodes<T>, number)
        local Cur = Offset
        const Result = {}
        const Keys = Keys
        const Reads = Reads
        for i, Key in Keys do
            Result[Key], Cur = Reads[i](Buffer, Cur)
        end
        return Result :: GetTypeFromTypeNodes<T>, Cur
    end

    function Object.DeltaSerialize(Data: { [string]: any }, Offset: number?): buffer
        local Cur = Offset or 0
        const Start = Cur
        Cur += 1
        local Len = 0
        const WBuf = WriteBuffer
        const KeyIndex = KeyIndex
        const Writes = Writes
        for Key, Value in Data do
            Len += 1
            const Index = KeyIndex[Key]
            buffer.writeu8(WBuf, Cur, Index)
            Cur += 1
            Cur = Writes[Index](Value, WBuf, Cur)
        end
        buffer.writeu8(WBuf, Start, Len)
        const Buf = CreateBuffer(Cur)
        CopyBuffer(Buf, 0, WBuf, 0, Cur)
        return Buf
    end

    function Object.DeltaPush(Buffer: buffer, Data: Optional<GetTypeFromTypeNodes<T>>, Offset: number): number
        const Cur = Offset
        Offset += 1
        local Len = 0
        const KeyIndex = KeyIndex
        const Writes = Writes
        for Key, Value in Data :: { [string]: any } do
            Len += 1
            const Index = KeyIndex[Key]
            buffer.writeu8(Buffer, Offset, Index)
            Offset += 1
            Offset = Writes[Index](Value, Buffer, Offset)
        end
        buffer.writeu8(Buffer, Cur, Len)
        return Offset
    end

    function Object.DeltaDeserialize(Buffer: buffer, Offset: number?): (Optional<GetTypeFromTypeNodes<T>>, number)
        local Cur = Offset or 0
        const Len = buffer.readu8(Buffer, Cur)
        Cur += 1
        const Result = {}
        const Keys = Keys
        const Reads = Reads
        for i = 1, Len do
            const Index = buffer.readu8(Buffer, Cur)
            Cur += 1
            Result[Keys[Index]], Cur = Reads[Index](Buffer, Cur)
        end
        return Result :: Optional<GetTypeFromTypeNodes<T>>, Cur
    end

    return Object :: Schema<GetTypeFromTypeNodes<T>>
end

--- Replaces the reusable serialization scratch buffer with a new capacity.
---
--- The default capacity is 1,000,000 bytes. Set a different size before
--- serialization when your payload limit differs.
--- @tag Core
--- @param NewSize number -- New scratch-buffer size in bytes.
function VoidSentryUltimate.SetWriteBufferSize(NewSize: number): ()
    WriteBuffer = CreateBuffer(NewSize)
end

---------------------------------------------------------
-- INIT
---------------------------------------------------------
if INSTANCE_SERIALIZATION_ENABLED then
    if RunService:IsClient() then
        const function RetryGetAttribute(Co: thread, Descendant: Instance): ()
            TaskSpawn(Co, Descendant.GetAttribute, Descendant, INSTANCE_ATTRIBUTE_NAME)
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

        const function OnRemoving(Descendant: Instance): ()
            const Id = InstanceMap[Descendant]
            if Id then
                IdMap[Id] = nil
            end
            InstanceMap[Descendant] = nil
        end

        for _, Descendant in game:GetDescendants() do
            TaskSpawn(OnInstance, Descendant)
        end
        game.DescendantAdded:Connect(OnInstance)
        game.DescendantRemoving:Connect(OnRemoving)
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
                IdMap[Id] = nil
                table.insert(FreeIds, Id)
                FreeIdsCount += 1
            end
            InstanceMap[Descendant] = nil
        end

        for _, Descendant in game:GetDescendants() do
            TaskSpawn(OnInstance, Descendant)
        end
        game.DescendantAdded:Connect(OnInstance)
        game.DescendantRemoving:Connect(OnRemoving)
    end
end

TableFreeze(Types)
TableFreeze(VoidSentryUltimate)

return VoidSentryUltimate :: Lib

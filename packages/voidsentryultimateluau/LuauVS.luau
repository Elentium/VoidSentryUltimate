--!native
--!optimize 2
--[[
    VoidSentryUltimate 
    [ Pure Luau implementation ]
    [ V1.1.2 ]
    [ by IAMNOTULTRA3 a.k.a Elentium, Elite ]
    [ Apache-2.0 License ]

    Docs: https://Elentium.github.io/VoidSentryUltimate
]]

--- Schema-based, validation-free serialization for Pure Luau.
---
--- Build a `SerdesNode` from `VoidSentryUltimate.Types`, then use the same
--- schema to serialize and deserialize a value. The module does not include Roblox types.
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

type function GetProperTypeFromUnion(Union: type): type
    if Union.tag ~= "union" then
        return Union
    end

    const Components = Union:components()
    const First = Components[1]
    if First.tag == "any" then
        return Components[2]
    end

    return First
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
    -- Tbl:setindexer(types.string, types.any)

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
    read DeltaPush: (Buffer: buffer, Data: Optional<T>, Offset: number) -> number,
    read Migrate: (OtherSchema: any, OldBuf: buffer, OldOffset: number?, NewOffset: number?) -> buffer
}

export type Lib = {
    read Serialize: <T>(Node: SerdesNode<any> & T, Data: GetTypeFromTypeNode<T>) -> buffer,
    read SerializeWithOffset: <T>(Node: SerdesNode<any> & T, Data: GetTypeFromTypeNode<T>, Offset: number) -> buffer,
    read Deserialize: <T>(Node: SerdesNode<T>, Buffer: buffer) -> (GetProperTypeFromUnion<T>, number),
    read DeserializeWithOffset: <T>(Node: SerdesNode<T>, Buffer: buffer, Offset: number) -> (GetProperTypeFromUnion<T>, number),
    read Push: <T>(Node: SerdesNode<any> & T, Data: GetTypeFromTypeNode<T>, Buffer: buffer, Offset: number?) -> number,
    read SetWriteBufferSize: (NewSize: number) -> (),
    read Schema: <T>(Tbl: T & { [string]: SerdesNode<any> }) -> Schema<GetTypeFromTypeNodes<T>>,
    read Migrate: (Old: SerdesNode<any>, New: SerdesNode<any>, OldBuf: buffer, OldOffset: number?, NewOffset: number?) -> buffer,

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
        read Number: SerdesNode<number>,
        read Int: SerdesNode<number>,
        read UInt: SerdesNode<number>,
        read Bool: SerdesNode<boolean>,
        read BoolPacked: SerdesNode<{ boolean }>,
        read String: SerdesNode<string>,
        read String8: SerdesNode<string>,
        read String24: SerdesNode<string>,
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
        read Color3Round: SerdesNode<Color3>,
        read Enum: <T>(EnumType: T & Enum) -> SerdesNode<GetEnumItem<T>>,
        read Enum8: <T>(EnumType: T & Enum) -> SerdesNode<GetEnumItem<T>>
    },
}

---------------------------------------------------------
-- LOCALIZING BUILTINS
---------------------------------------------------------
const CreateTable = table.create
const TableFreeze = table.freeze
const CreateBuffer = buffer.create
const CopyBuffer = buffer.copy
const BufferLen = buffer.len

---------------------------------------------------------
-- STATE
---------------------------------------------------------
local WriteBuffer = CreateBuffer(BIG_BUFFER_SIZE) -- scratch buffer that is used during serialization
const FloatConverter = CreateBuffer(4) -- used to convert f32 to smaller precision version

---------------------------------------------------------
-- NODES
const I8: SerdesNode<number> = {}

do
	const function I8Ser(Value: number, Buf: buffer, Cur: number): number
		buffer.writei8(Buf, Cur, Value)
		return Cur + 1
	end

	const function I8Des(Buf: buffer, Cur: number): (number, number)
		const Value = buffer.readi8(Buf, Cur)
		return Value, Cur + 1
	end

	I8[SER] = I8Ser
	I8[DES] = I8Des
end

const U8: SerdesNode<number> = {}

do
	const function U8Ser(Value: number, Buf: buffer, Cur: number): number
		buffer.writeu8(Buf, Cur, Value)
		return Cur + 1
	end

	const function U8Des(Buf: buffer, Cur: number): (number, number)
		const Value = buffer.readu8(Buf, Cur)
		return Value, Cur + 1
	end

	U8[SER] = U8Ser
	U8[DES] = U8Des
end

const U16: SerdesNode<number> = {}

do
	const function U16Ser(Value: number, Buf: buffer, Cur: number): number
		buffer.writeu16(Buf, Cur, Value)
		return Cur + 2
	end

	const function U16Des(Buf: buffer, Cur: number): (number, number)
		const Value = buffer.readu16(Buf, Cur)
		return Value, Cur + 2
	end

	U16[SER] = U16Ser
	U16[DES] = U16Des
end

const I16: SerdesNode<number> = {}

do
	const function I16Ser(Value: number, Buf: buffer, Cur: number): number
		buffer.writei16(Buf, Cur, Value)
		return Cur + 2
	end

	const function I16Des(Buf: buffer, Cur: number): (number, number)
		const Value = buffer.readi16(Buf, Cur)
		return Value, Cur + 2
	end

	I16[SER] = I16Ser
	I16[DES] = I16Des
end

const U32: SerdesNode<number> = {}

do
	const function U32Ser(Value: number, Buf: buffer, Cur: number): number
		buffer.writeu32(Buf, Cur, Value)
		return Cur + 4
	end

	const function U32Des(Buf: buffer, Cur: number): (number, number)
		const Value = buffer.readu32(Buf, Cur)
		return Value, Cur + 4
	end

	U32[SER] = U32Ser
	U32[DES] = U32Des
end

const I32: SerdesNode<number> = {}

do
	const function I32Ser(Value: number, Buf: buffer, Cur: number): number
		buffer.writei32(Buf, Cur, Value)
		return Cur + 4
	end

	const function I32Des(Buf: buffer, Cur: number): (number, number)
		const Value = buffer.readi32(Buf, Cur)
		return Value, Cur + 4
	end

	I32[SER] = I32Ser
	I32[DES] = I32Des
end

const I40: SerdesNode<number> = {}

do
	const function I40Ser(Value: number, Buf: buffer, Cur: number): number
		buffer.writeu32(Buf, Cur, Value)
        buffer.writeu8(Buf, Cur + 4, Value // 0x100000000)
		return Cur + 5
	end

	const function I40Des(Buf: buffer, Cur: number): (number, number)
		return buffer.readu32(Buf, Cur) + buffer.readi8(Buf, Cur + 4) * 0x100000000, Cur + 5
	end

	I40[SER] = I40Ser
	I40[DES] = I40Des
end

const U40: SerdesNode<number> = {}

do
	const function U40Ser(Value: number, Buf: buffer, Cur: number): number
		buffer.writeu32(Buf, Cur, Value)
        buffer.writeu8(Buf, Cur + 4, Value // 0x100000000)
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
		buffer.writeu32(Buf, Cur, Value)
        buffer.writeu16(Buf, Cur + 4, Value // 0x100000000)
		return Cur + 6
	end

	const function I48Des(Buf: buffer, Cur: number): (number, number)
		return buffer.readu32(Buf, Cur) + buffer.readi16(Buf, Cur + 4) * 0x100000000, Cur + 6
	end

    I48[SER] = I48Ser
	I48[DES] = I48Des
end

const U48: SerdesNode<number> = {}

do
	const function U48Ser(Value: number, Buf: buffer, Cur: number): number
		buffer.writeu32(Buf, Cur, Value)
        buffer.writeu16(Buf, Cur + 4, Value // 0x100000000)
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
		return Cur + 4
	end

	const function F32Des(Buf: buffer, Cur: number): (number, number)
		const Value = buffer.readf32(Buf, Cur)
		return Value, Cur + 4
	end

	F32[SER] = F32Ser
	F32[DES] = F32Des
end

const F64: SerdesNode<number> = {}

do
	const function F64Ser(Value: number, Buf: buffer, Cur: number): number
		buffer.writef64(Buf, Cur, Value)
		return Cur + 8
	end

	const function F64Des(Buf: buffer, Cur: number): (number, number)
		const Value = buffer.readf64(Buf, Cur)
		return Value, Cur + 8
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
        return Cur + Len
	end

	const function StringDes(Buf: buffer, Cur: number): (string, number)
		const Len = buffer.readu16(Buf, Cur)
        Cur += 2
        const Value = buffer.readstring(Buf, Cur, Len)
		return Value, Cur + Len
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
        return Cur + Len
	end

	const function String8Des(Buf: buffer, Cur: number): (string, number)
		const Len = buffer.readu8(Buf, Cur)
        Cur += 1
        const Value = buffer.readstring(Buf, Cur, Len)
		return Value, Cur + Len
	end

	String8[SER] = String8Ser
	String8[DES] = String8Des
end

const String24: SerdesNode<string> = {}

do
	const function String24Ser(Value: string, Buf: buffer, Cur: number): number
        const Len = #Value
        buffer.writeu16(Buf, Cur, Len)
        buffer.writeu8(Buf, Cur + 2, bit32.rshift(Len, 16))
        Cur += 3
		buffer.writestring(Buf, Cur, Value)
        return Cur + Len
	end

	const function String24Des(Buf: buffer, Cur: number): (string, number)
		const Len = buffer.readu16(Buf, Cur) + buffer.readu8(Buf, Cur + 2) * 65536
        Cur += 3
        const Value = buffer.readstring(Buf, Cur, Len)
		return Value, Cur + Len
	end

	String24[SER] = String24Ser
	String24[DES] = String24Des
end

const function StringFixed(Length: number): SerdesNode<string>
    const StringFixedNode: SerdesNode<string> = {}

    const function StringFixedSer(Value: string, Buf: buffer, Cur: number): number
		buffer.writestring(Buf, Cur, Value)
		return Cur + Length
    end

	const function StringFixedDes(Buf: buffer, Cur: number): (string, number)
        const Length = Length
        const Value = buffer.readstring(Buf, Cur, Length)
		return Value, Cur + Length
	end

	StringFixedNode[SER] = StringFixedSer
	StringFixedNode[DES] = StringFixedDes

    return StringFixedNode
end

const function Array<T>(Node: SerdesNode<T>): SerdesNode<{ T }>
    const ArrayNode: SerdesNode<{ T }> = {}

    const Ser = Node[SER] :: Ser<T>
    const Des = Node[DES] :: Des<T>

    const function ArraySer(Array: { T }, Buf: buffer, Cur: number): number
        const Len = #Array
        buffer.writeu16(Buf, Cur, Len)
        Cur += 2
        const Ser = Ser
        for _, Value in Array do
            Cur = Ser(Value, Buf, Cur)
        end
        return Cur
    end

    const function ArrayDes(Buf: buffer, Cur: number): ({ T }, number)
        const Len = buffer.readu16(Buf, Cur)
        const Array = CreateTable<<T>>(Len)
        Cur += 2
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

const function Array8<T>(Node: SerdesNode<T>): SerdesNode<{ T }>
    const Array8Node: SerdesNode<{ T }> = {}

    const Ser = Node[SER] :: Ser<T>
    const Des = Node[DES] :: Des<T>

    const function Array8Ser(Array: { T }, Buf: buffer, Cur: number): number
        const Len = #Array
        buffer.writeu8(Buf, Cur, Len)
        Cur += 1
        const Ser = Ser
        for _, Value in Array do
            Cur = Ser(Value, Buf, Cur)
        end
        return Cur
    end

    const function Array8Des(Buf: buffer, Cur: number): ({ T }, number)
        const Len = buffer.readu8(Buf, Cur)
        const Array = CreateTable<<T>>(Len)
        Cur += 1
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

const function Array24<T>(Node: SerdesNode<T>): SerdesNode<{ T }>
    const Array24Node: SerdesNode<{ T }> = {}

    const Ser = Node[SER] :: Ser<T>
    const Des = Node[DES] :: Des<T>

    const function Array24Ser(Array: { T }, Buf: buffer, Cur: number): number
        const Len = #Array
        buffer.writeu16(Buf, Cur, Len)
        buffer.writeu8(Buf, Cur + 2, bit32.rshift(Len, 16))
        Cur += 3
        const Ser = Ser
        for _, Value in Array do
            Cur = Ser(Value, Buf, Cur)
        end
        return Cur
    end

    const function Array24Des(Buf: buffer, Cur: number): ({ T }, number)
        const Len = buffer.readu16(Buf, Cur) + buffer.readu8(Buf, Cur + 2) * 65536
        const Array = CreateTable<<T>>(Len)
        Cur += 3
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
        Cur += 1
        local Len = 0
        const Lookup = Lookup
        const Writes = Writes
        for Key, Field in Value :: { [string]: any } do
            const Id = Lookup[Key]
            Len += 1
            buffer.writeu8(Buf, Cur, Id)
            Cur = Writes[Id](Field, Buf, Cur + 1)
        end
        buffer.writeu8(Buf, Start, Len)
        return Cur
    end

    const function DeltaStructDes(Buf: buffer, Cur: number): (Optional<GetTypeFromTypeNodes<T>> & { [string]: nil }, number)
        const Result = {}
        const Len = buffer.readu8(Buf, Cur)
        const Keys = Keys
        const Reads = Reads
        Cur += 1
        for _ = 1, Len do
            const Id = buffer.readu8(Buf, Cur)
            Cur += 1
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
        Cur += 2
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
        Cur += 2
        const Keys = Keys
        const Reads = Reads
        for _ = 1, Len do
            const Id = buffer.readu16(Buf, Cur)
            Cur += 2
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
        return Cur + 12
    end

    const function VectorDes(Buf: buffer, Cur: number): (Vector3, number)
        const x = buffer.readf32(Buf, Cur)
        const y = buffer.readf32(Buf, Cur + 4)
        const z = buffer.readf32(Buf, Cur + 8)
        return Vector3.new(x, y, z), Cur + 12
    end

    Vector[SER] = VectorSer
    Vector[DES] = VectorDes
end

const function Map<K, V>(KeyNode: SerdesNode<K>, ValueNode: SerdesNode<V>): SerdesNode<{ [K]: V }>
    const MapNode: SerdesNode<{ [K]: V }> = {}

    const KeySer = KeyNode[SER] :: Ser<K>
    const KeyDes = KeyNode[DES] :: Des<K>

    const ValueSer = ValueNode[SER] :: Ser<V>
    const ValueDes = ValueNode[DES] :: Des<V>

    const function MapSer(Map: { [K]: V }, Buf: buffer, Cur: number): number
        const Start = Cur
        local Len = 0
        Cur += 2
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
        Cur += 2
        const KeyDes = KeyDes
        const ValueDes = ValueDes
        local Key, Val
        for _ = 1, Len do
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

const function Map8<K, V>(KeyNode: SerdesNode<K>, ValueNode: SerdesNode<V>): SerdesNode<{ [K]: V }>
    const Map8Node: SerdesNode<{ [K]: V }> = {}

    const KeySer = KeyNode[SER] :: Ser<K>
    const KeyDes = KeyNode[DES] :: Des<K>

    const ValueSer = ValueNode[SER] :: Ser<V>
    const ValueDes = ValueNode[DES] :: Des<V>

    const function Map8Ser(Map: { [K]: V }, Buf: buffer, Cur: number): number
        const Start = Cur
        local Len = 0
        Cur += 1
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
        Cur += 1
        const KeyDes = KeyDes
        const ValueDes = ValueDes
        local Key, Val
        for _ = 1, Len do
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

const function Map24<K, V>(KeyNode: SerdesNode<K>, ValueNode: SerdesNode<V>): SerdesNode<{ [K]: V }>
    const Map24Node: SerdesNode<{ [K]: V }> = {}

    const KeySer = KeyNode[SER] :: Ser<K>
    const KeyDes = KeyNode[DES] :: Des<K>

    const ValueSer = ValueNode[SER] :: Ser<V>
    const ValueDes = ValueNode[DES] :: Des<V>

    const function Map24Ser(Map: { [K]: V }, Buf: buffer, Cur: number): number
        const Start = Cur
        local Len = 0
        Cur += 3
        const KeySer = KeySer
        const ValueSer = ValueSer
        for Key, Value in Map do
            Len += 1
            Cur = KeySer(Key, Buf, Cur)
            Cur = ValueSer(Value, Buf, Cur)
        end
        buffer.writeu16(Buf, Start, Len)
        buffer.writeu8(Buf, Start + 2, bit32.rshift(Len, 16))
    
        return Cur
    end

    const function Map24Des(Buf: buffer, Cur: number): ({ [K]: V }, number)
        const Len = buffer.readu16(Buf, Cur) + buffer.readu8(Buf, Cur + 2) * 65536
        const Map = {}
        Cur += 3
        const KeyDes = KeyDes
        const ValueDes = ValueDes
        local Key, Val
        for _ = 1, Len do
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
        const Length = Length
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
        local Key, Val
        for _ = 1, Length do
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

const F16Scale = CreateTable(64, 0)
for i = 0, 63 do
    const e = i % 32
    const s = if e == 0 then 0 else math.ldexp(1, e - 25)
    F16Scale[i + 1] = if i >= 32 and e ~= 0 then -s else s
end

const F24Scale = CreateTable(512, 0)
for i = 0, 511 do
    const e = i % 256
    const s = if e == 0 then 0 else math.ldexp(1, e - 142)
    F24Scale[i + 1] = if i >= 256 and e ~= 0 then -s else s
end

const F16: SerdesNode<number> = {}
do
    const function F16Ser(Value: number, Buf: buffer, Cur: number): number
        const FloatConverter = FloatConverter
        buffer.writef32(FloatConverter, 0, Value)
        const Bits = buffer.readu32(FloatConverter, 0)

        const Sign = bit32.band(bit32.rshift(Bits, 16), 0x8000)
        const Abs = bit32.band(Bits, 0x7FFFFFFF) + 0x1000

        buffer.writeu16(Buf, Cur, if Abs >= 0x47800000 then Sign + 0x7BFF elseif Abs < 0x38800000 then Sign else Sign + bit32.rshift(Abs, 13) - 0x1C000)
        return Cur + 2
    end

    const function F16Deser(Buf: buffer, Cur: number): (number, number)
        const Packed = buffer.readu16(Buf, Cur)
        return bit32.bor(bit32.band(Packed, 0x3FF), 0x400) * F16Scale[bit32.rshift(Packed, 10) + 1], Cur + 2
    end

    F16[SER] = F16Ser
    F16[DES] = F16Deser
end

const F24: SerdesNode<number> = {}
do
    const function F24Ser(Value: number, Buf: buffer, Cur: number): number
        const FloatConverter = FloatConverter
        buffer.writef32(FloatConverter, 0, Value)
        buffer.writeu16(Buf, Cur, buffer.readu16(FloatConverter, 1))
        buffer.writeu8(Buf, Cur + 2, buffer.readu8(FloatConverter, 3))
        return Cur + 3
    end

    const function F24Deser(Buf: buffer, Cur: number): (number, number)
        const Packed = buffer.readu16(Buf, Cur) + buffer.readu8(Buf, Cur + 2) * 65536
        return bit32.bor(bit32.band(Packed, 0x7FFF), 0x8000) * F24Scale[bit32.rshift(Packed, 15) + 1], Cur + 3
    end

    F24[SER] = F24Ser
    F24[DES] = F24Deser
end

const U24: SerdesNode<number> = {}
do
    const function U24Ser(Value: number, Buf: buffer, Cur: number): number
        buffer.writeu16(Buf, Cur, Value)
        buffer.writeu8(Buf, Cur + 2, bit32.rshift(Value, 16))
        return Cur + 3
    end

    const function U24Deser(Buf: buffer, Cur: number): (number, number)
        return buffer.readu16(Buf, Cur) + buffer.readu8(Buf, Cur + 2) * 65536, Cur + 3
    end

    U24[SER] = U24Ser
    U24[DES] = U24Deser
end

const I24: SerdesNode<number> = {}
do
    const function I24Ser(Value: number, Buf: buffer, Cur: number): number
        -- exactly the same as U24
        buffer.writeu16(Buf, Cur, Value)
        buffer.writeu8(Buf, Cur + 2, bit32.rshift(Value, 16))
        return Cur + 3
    end

    const function I24Deser(Buf: buffer, Cur: number): (number, number)
        return buffer.readu16(Buf, Cur) + buffer.readi8(Buf, Cur + 2) * 65536, Cur + 3
    end

    I24[SER] = I24Ser
    I24[DES] = I24Deser
end

const VectorF24: SerdesNode<Vector3> = {}
do
    const function VectorF24Ser(Value: Vector3, Buf: buffer, Cur: number): number
        const FloatConverter = FloatConverter
        buffer.writef32(Buf, Cur + 5, Value.Z)
        buffer.writef32(Buf, Cur + 2, Value.Y)
        buffer.writef32(FloatConverter, 0, Value.X)
        buffer.writeu16(Buf, Cur, buffer.readu16(FloatConverter, 1))
        buffer.writeu8(Buf, Cur + 2, buffer.readu8(FloatConverter, 3))
        return Cur + 9
    end

    const function VectorF24Des(Buf: buffer, Cur: number): (Vector3, number)
        const Scale = F24Scale
        const Px = bit32.band(buffer.readu32(Buf, Cur), 0xFFFFFF)
        const x = bit32.bor(bit32.band(Px, 0x7FFF), 0x8000) * Scale[bit32.rshift(Px, 15) + 1]
        const Py = bit32.rshift(buffer.readu32(Buf, Cur + 2), 8)
        const y = bit32.bor(bit32.band(Py, 0x7FFF), 0x8000) * Scale[bit32.rshift(Py, 15) + 1]
        const Pz = bit32.rshift(buffer.readu32(Buf, Cur + 5), 8)
        const z = bit32.bor(bit32.band(Pz, 0x7FFF), 0x8000) * Scale[bit32.rshift(Pz, 15) + 1]

        return Vector3.new(x, y, z), Cur + 9
    end

    VectorF24[SER] = VectorF24Ser
    VectorF24[DES] = VectorF24Des
end

const VectorF16: SerdesNode<Vector3> = {}
do
    const function VectorF16Ser(Value: Vector3, Buf: buffer, Cur: number): number
        const FloatConverter = FloatConverter

        do
            buffer.writef32(FloatConverter, 0, Value.X)
            const Bits = buffer.readu32(FloatConverter, 0)
            const Sign = bit32.band(bit32.rshift(Bits, 16), 0x8000)
            const Abs = bit32.band(Bits, 0x7FFFFFFF) + 0x1000
            buffer.writeu16(Buf, Cur, if Abs >= 0x47800000 then Sign + 0x7BFF elseif Abs < 0x38800000 then Sign else Sign + bit32.rshift(Abs, 13) - 0x1C000)
        end
        do
            buffer.writef32(FloatConverter, 0, Value.Y)
            const Bits = buffer.readu32(FloatConverter, 0)
            const Sign = bit32.band(bit32.rshift(Bits, 16), 0x8000)
            const Abs = bit32.band(Bits, 0x7FFFFFFF) + 0x1000
            buffer.writeu16(Buf, Cur + 2, if Abs >= 0x47800000 then Sign + 0x7BFF elseif Abs < 0x38800000 then Sign else Sign + bit32.rshift(Abs, 13) - 0x1C000)
        end
        do
            buffer.writef32(FloatConverter, 0, Value.Z)
            const Bits = buffer.readu32(FloatConverter, 0)
            const Sign = bit32.band(bit32.rshift(Bits, 16), 0x8000)
            const Abs = bit32.band(Bits, 0x7FFFFFFF) + 0x1000
            buffer.writeu16(Buf, Cur + 4, if Abs >= 0x47800000 then Sign + 0x7BFF elseif Abs < 0x38800000 then Sign else Sign + bit32.rshift(Abs, 13) - 0x1C000)
        end

        return Cur + 6
    end

    const function VectorF16Des(Buf: buffer, Cur: number): (Vector3, number)
        const Scale = F16Scale
        const Px = buffer.readu16(Buf, Cur)
        const x = bit32.bor(bit32.band(Px, 0x3FF), 0x400) * Scale[bit32.rshift(Px, 10) + 1]
        const Py = buffer.readu16(Buf, Cur + 2)
        const y = bit32.bor(bit32.band(Py, 0x3FF), 0x400) * Scale[bit32.rshift(Py, 10) + 1]
        const Pz = buffer.readu16(Buf, Cur + 4)
        const z = bit32.bor(bit32.band(Pz, 0x3FF), 0x400) * Scale[bit32.rshift(Pz, 10) + 1]

        return Vector3.new(x, y, z), Cur + 6
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
        return Cur + 6
    end

    const function VectorU16Des(Buf: buffer, Cur: number): (Vector3, number)
        const x = buffer.readu16(Buf, Cur)
        const y = buffer.readu16(Buf, Cur + 2)
        const z = buffer.readu16(Buf, Cur + 4)
        return Vector3.new(x, y, z), Cur + 6
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
        return Cur + 6
    end

    const function VectorI16Des(Buf: buffer, Cur: number): (Vector3, number)
        const x = buffer.readi16(Buf, Cur)
        const y = buffer.readi16(Buf, Cur + 2)
        const z = buffer.readi16(Buf, Cur + 4)
        return Vector3.new(x, y, z), Cur + 6
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
        return Cur + 3
    end

    const function VectorU8Des(Buf: buffer, Cur: number): (Vector3, number)
        const x = buffer.readu8(Buf, Cur)
        const y = buffer.readu8(Buf, Cur + 1)
        const z = buffer.readu8(Buf, Cur + 2)
        return Vector3.new(x, y, z), Cur + 3
    end

    VectorU8[SER] = VectorU8Ser
    VectorU8[DES] = VectorU8Des
end

const VectorI8: SerdesNode<Vector3> = {}
do
    const function VectorI8Ser(Value: Vector3, Buf: buffer, Cur: number): number
        buffer.writei8(Buf, Cur, Value.X)
        buffer.writei8(Buf, Cur + 1, Value.Y)
        buffer.writei8(Buf, Cur + 2, Value.Z)
        return Cur + 3
    end

    const function VectorI8Des(Buf: buffer, Cur: number): (Vector3, number)
        const x = buffer.readi8(Buf, Cur)
        const y = buffer.readi8(Buf, Cur + 1)
        const z = buffer.readi8(Buf, Cur + 2)
        return Vector3.new(x, y, z), Cur + 3
    end

    VectorI8[SER] = VectorI8Ser
    VectorI8[DES] = VectorI8Des
end

const VectorU24: SerdesNode<Vector3> = {}
do
    const function VectorU24Ser(Value: Vector3, Buf: buffer, Cur: number): number
        buffer.writeu32(Buf, Cur, Value.X)
        buffer.writeu32(Buf, Cur + 3, Value.Y)
        const z = Value.Z
        buffer.writeu16(Buf, Cur + 6, z)
        buffer.writeu8(Buf, Cur + 8, bit32.rshift(z, 16))
        return Cur + 9
    end

    const function VectorU24Des(Buf: buffer, Cur: number): (Vector3, number)
        const x = bit32.band(buffer.readu32(Buf, Cur), 0xFFFFFF)
        const y = bit32.band(buffer.readu32(Buf, Cur + 3), 0xFFFFFF)
        const z = bit32.rshift(buffer.readu32(Buf, Cur + 5), 8)
        return Vector3.new(x, y, z), Cur + 9
    end

    VectorU24[SER] = VectorU24Ser
    VectorU24[DES] = VectorU24Des
end

const VectorI24: SerdesNode<Vector3> = {}
do
    const function VectorI24Ser(Value: Vector3, Buf: buffer, Cur: number): number
        buffer.writeu32(Buf, Cur, Value.X)
        buffer.writeu32(Buf, Cur + 3, Value.Y)
        const z = Value.Z
        buffer.writeu16(Buf, Cur + 6, z)
        buffer.writeu8(Buf, Cur + 8, bit32.rshift(z, 16))
        return Cur + 9
    end

    const function VectorI24Des(Buf: buffer, Cur: number): (Vector3, number)
        const x = buffer.readu16(Buf, Cur) + buffer.readi8(Buf, Cur + 2) * 65536
        const y = buffer.readi32(Buf, Cur + 2) // 256
        const z = buffer.readi32(Buf, Cur + 5) // 256
        return Vector3.new(x, y, z), Cur + 9
    end

    VectorI24[SER] = VectorI24Ser
    VectorI24[DES] = VectorI24Des
end

const Bool: SerdesNode<boolean> = {}
do
    const function BoolSer(Value: boolean, Buf: buffer, Cur: number): number
        buffer.writeu8(Buf, Cur, Value and 1 or 0)
        return Cur + 1
    end

    const function BoolDes(Buf: buffer, Cur: number): (boolean, number)
        const Value = buffer.readu8(Buf, Cur)
        return Value == 1, Cur + 1
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
        return Cur + 1
    end

    const function BoolPackedDes(Buf: buffer, Cur: number): ({ boolean }, number)
        const Byte = buffer.readu8(Buf, Cur)
        return { 
			bit32.btest(Byte, 1),
			bit32.btest(Byte, 2),
			bit32.btest(Byte, 4),
			bit32.btest(Byte, 8),
			bit32.btest(Byte, 16),
			bit32.btest(Byte, 32),
			bit32.btest(Byte, 64),
			bit32.btest(Byte, 128), 
        }, Cur + 1
    end

    BoolPacked[SER] = BoolPackedSer
    BoolPacked[DES] = BoolPackedDes
end

const Buffer: SerdesNode<buffer> = {}
do
    const function BufferSer(Value: buffer, Buf: buffer, Cur: number): number
        const Len = BufferLen(Value)
        buffer.writeu16(Buf, Cur, Len)
        Cur += 2
        CopyBuffer(Buf, Cur, Value, 0, Len)
        return Cur + Len
    end

    const function BufferDes(Buf: buffer, Cur: number): (buffer, number)
        const Length = buffer.readu16(Buf, Cur)
        Cur += 2
        const Value = CreateBuffer(Length)
        CopyBuffer(Value, 0, Buf, Cur, Length)
        return Value, Cur + Length
    end

    Buffer[SER] = BufferSer
    Buffer[DES] = BufferDes
end

const Buffer8: SerdesNode<buffer> = {}
do
    const function Buffer8Ser(Value: buffer, Buf: buffer, Cur: number): number
        const Len = BufferLen(Value)
        buffer.writeu8(Buf, Cur, Len)
        Cur += 1
        CopyBuffer(Buf, Cur, Value, 0, Len)
        return Cur + Len
    end

    const function Buffer8Des(Buf: buffer, Cur: number): (buffer, number)
        const Length = buffer.readu8(Buf, Cur)
        Cur += 1
        const Value = CreateBuffer(Length)
        CopyBuffer(Value, 0, Buf, Cur, Length)
        return Value, Cur + Length
    end

    Buffer8[SER] = Buffer8Ser
    Buffer8[DES] = Buffer8Des
end

const Buffer24: SerdesNode<buffer> = {}
do
    const function Buffer24Ser(Value: buffer, Buf: buffer, Cur: number): number
        const Len = BufferLen(Value)
        buffer.writeu16(Buf, Cur, Len)
        buffer.writeu8(Buf, Cur + 2, bit32.rshift(Len, 16))
        Cur += 3
        CopyBuffer(Buf, Cur, Value, 0, Len)
        return Cur + Len
    end

    const function Buffer24Des(Buf: buffer, Cur: number): (buffer, number)
        const Length = buffer.readu16(Buf, Cur) + buffer.readu8(Buf, Cur + 2) * 65536
        const Value = CreateBuffer(Length)
        Cur += 3
        CopyBuffer(Value, 0, Buf, Cur, Length)
        return Value, Cur + Length
    end

    Buffer24[SER] = Buffer24Ser
    Buffer24[DES] = Buffer24Des
end

const function BufferFixed(Length: number): SerdesNode<buffer>
    const BufferFixedNode: SerdesNode<buffer> = {}

    const function BufferFixedSer(Value: buffer, Buf: buffer, Cur: number): number
        CopyBuffer(Buf, Cur, Value, 0, Length)
        Cur +=Length
        return Cur
    end

    const function BufferFixedDes(Buf: buffer, Cur: number): (buffer, number)
        const Value = CreateBuffer(Length)
        CopyBuffer(Value, 0, Buf, Cur, Length)
        return Value, Cur + Length
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
        Cur += 1
        if Exists then
            const Ser = Node[SER] :: Ser<T>
            Cur = Ser(Value :: T, Buf, Cur)
        end
    
        return Cur
    end

    const function OptionalDes(Buf: buffer, Cur: number): (T?, number)
        const Exists = buffer.readu8(Buf, Cur)
        Cur += 1
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

const UInt: SerdesNode<number> = {}
do
    const function UIntSer(Value: number, Buf: buffer, Cur: number): number
        if Value < 0 then
            error("Unsigned Integer type cannot Serialize negative value")
        elseif Value < 0x80 then
            buffer.writeu8(Buf, Cur, Value)
            return Cur + 1
        elseif Value < 0x4000 then
            buffer.writeu16(Buf, Cur, bit32.bor(bit32.band(Value, 0x7F), bit32.band(bit32.lshift(Value, 1), 0x7F00), 0x80))
            return Cur + 2
        elseif Value < 0x200000 then
            buffer.writeu16(Buf, Cur, bit32.bor(bit32.band(Value, 0x7F), bit32.band(bit32.lshift(Value, 1), 0x7F00), 0x8080))
            buffer.writeu8(Buf, Cur + 2, bit32.rshift(Value, 14))
            return Cur + 3
        elseif Value < 0x10000000 then
            buffer.writeu32(Buf, Cur, bit32.bor(
                bit32.band(Value, 0x7F),
                bit32.band(bit32.lshift(Value, 1), 0x7F00),
                bit32.band(bit32.lshift(Value, 2), 0x7F0000),
                bit32.lshift(bit32.rshift(Value, 21), 24),
                0x808080
            ))
            return Cur + 4
        end

        buffer.writeu32(Buf, Cur, bit32.bor(
            bit32.band(Value, 0x7F),
            bit32.band(bit32.lshift(Value, 1), 0x7F00),
            bit32.band(bit32.lshift(Value, 2), 0x7F0000),
            bit32.band(bit32.lshift(Value, 3), 0x7F000000),
            0x80808080
        ))

        const Hi = Value // 0x10000000
        if Hi < 0x80 then
            buffer.writeu8(Buf, Cur + 4, Hi)
            return Cur + 5
        elseif Hi < 0x4000 then
            buffer.writeu16(Buf, Cur + 4, bit32.bor(bit32.band(Hi, 0x7F), bit32.band(bit32.lshift(Hi, 1), 0x7F00), 0x80))
            return Cur + 6
        elseif Hi < 0x200000 then
            buffer.writeu16(Buf, Cur + 4, bit32.bor(bit32.band(Hi, 0x7F), bit32.band(bit32.lshift(Hi, 1), 0x7F00), 0x8080))
            buffer.writeu8(Buf, Cur + 6, bit32.rshift(Hi, 14))
            return Cur + 7
        end

        buffer.writeu32(Buf, Cur + 4, bit32.bor(
            bit32.band(Hi, 0x7F),
            bit32.band(bit32.lshift(Hi, 1), 0x7F00),
            bit32.band(bit32.lshift(Hi, 2), 0x7F0000),
            bit32.lshift(bit32.rshift(Hi, 21), 24),
            0x808080
        ))
        return Cur + 8
    end

    const function UIntDes(Buf: buffer, Cur: number): (number, number)
        local Byte = buffer.readu8(Buf, Cur)
        if Byte < 0x80 then
            return Byte, Cur + 1
        end
        local Value = Byte

        Byte = buffer.readu8(Buf, Cur + 1)
        Value += Byte * 0x80
        if Byte < 0x80 then
            return Value - 0x80, Cur + 2
        end

        Byte = buffer.readu8(Buf, Cur + 2)
        Value += Byte * 0x4000
        if Byte < 0x80 then
            return Value - 0x4080, Cur + 3
        end

        Byte = buffer.readu8(Buf, Cur + 3)
        Value += Byte * 0x200000
        if Byte < 0x80 then
            return Value - 0x204080, Cur + 4
        end

        Byte = buffer.readu8(Buf, Cur + 4)
        Value += Byte * 0x10000000
        if Byte < 0x80 then
            return Value - 0x10204080, Cur + 5
        end

        Byte = buffer.readu8(Buf, Cur + 5)
        Value += Byte * 0x800000000
        if Byte < 0x80 then
            return Value - 0x810204080, Cur + 6
        end

        Byte = buffer.readu8(Buf, Cur + 6)
        Value += Byte * 0x40000000000
        if Byte < 0x80 then
            return Value - 0x40810204080, Cur + 7
        end

        return Value - 0x2040810204080 + buffer.readu8(Buf, Cur + 7) * 0x2000000000000, Cur + 8
    end

    UInt[SER] = UIntSer
    UInt[DES] = UIntDes
end

const Int: SerdesNode<number> = {}
do
    const function IntSer(Value: number, Buf: buffer, Cur: number): number
        Value = if Value < 0 then -2 * Value - 1 else 2 * Value

        if Value < 0x80 then
            buffer.writeu8(Buf, Cur, Value)
            return Cur + 1
        elseif Value < 0x4000 then
            buffer.writeu16(Buf, Cur, bit32.bor(bit32.band(Value, 0x7F), bit32.band(bit32.lshift(Value, 1), 0x7F00), 0x80))
            return Cur + 2
        elseif Value < 0x200000 then
            buffer.writeu16(Buf, Cur, bit32.bor(bit32.band(Value, 0x7F), bit32.band(bit32.lshift(Value, 1), 0x7F00), 0x8080))
            buffer.writeu8(Buf, Cur + 2, bit32.rshift(Value, 14))
            return Cur + 3
        elseif Value < 0x10000000 then
            buffer.writeu32(Buf, Cur, bit32.bor(
                bit32.band(Value, 0x7F),
                bit32.band(bit32.lshift(Value, 1), 0x7F00),
                bit32.band(bit32.lshift(Value, 2), 0x7F0000),
                bit32.lshift(bit32.rshift(Value, 21), 24),
                0x808080
            ))
            return Cur + 4
        end

        buffer.writeu32(Buf, Cur, bit32.bor(
            bit32.band(Value, 0x7F),
            bit32.band(bit32.lshift(Value, 1), 0x7F00),
            bit32.band(bit32.lshift(Value, 2), 0x7F0000),
            bit32.band(bit32.lshift(Value, 3), 0x7F000000),
            0x80808080
        ))

        const Hi = Value // 0x10000000
        if Hi < 0x80 then
            buffer.writeu8(Buf, Cur + 4, Hi)
            return Cur + 5
        elseif Hi < 0x4000 then
            buffer.writeu16(Buf, Cur + 4, bit32.bor(bit32.band(Hi, 0x7F), bit32.band(bit32.lshift(Hi, 1), 0x7F00), 0x80))
            return Cur + 6
        elseif Hi < 0x200000 then
            buffer.writeu16(Buf, Cur + 4, bit32.bor(bit32.band(Hi, 0x7F), bit32.band(bit32.lshift(Hi, 1), 0x7F00), 0x8080))
            buffer.writeu8(Buf, Cur + 6, bit32.rshift(Hi, 14))
            return Cur + 7
        end

        buffer.writeu32(Buf, Cur + 4, bit32.bor(
            bit32.band(Hi, 0x7F),
            bit32.band(bit32.lshift(Hi, 1), 0x7F00),
            bit32.band(bit32.lshift(Hi, 2), 0x7F0000),
            bit32.lshift(bit32.rshift(Hi, 21), 24),
            0x808080
        ))
        return Cur + 8
    end

    const function IntDes(Buf: buffer, Cur: number): (number, number)
        local Byte = buffer.readu8(Buf, Cur)
        local Value = Byte
        local Next = Cur + 1

        repeat
            if Byte < 0x80 then
                break
            end

            Byte = buffer.readu8(Buf, Cur + 1)
            Value += Byte * 0x80
            if Byte < 0x80 then
                Value -= 0x80
                Next = Cur + 2
                break
            end

            Byte = buffer.readu8(Buf, Cur + 2)
            Value += Byte * 0x4000
            if Byte < 0x80 then
                Value -= 0x4080
                Next = Cur + 3
                break
            end

            Byte = buffer.readu8(Buf, Cur + 3)
            Value += Byte * 0x200000
            if Byte < 0x80 then
                Value -= 0x204080
                Next = Cur + 4
                break
            end

            Byte = buffer.readu8(Buf, Cur + 4)
            Value += Byte * 0x10000000
            if Byte < 0x80 then
                Value -= 0x10204080
                Next = Cur + 5
                break
            end

            Byte = buffer.readu8(Buf, Cur + 5)
            Value += Byte * 0x800000000
            if Byte < 0x80 then
                Value -= 0x810204080
                Next = Cur + 6
                break
            end

            Byte = buffer.readu8(Buf, Cur + 6)
            Value += Byte * 0x40000000000
            if Byte < 0x80 then
                Value -= 0x40810204080
                Next = Cur + 7
                break
            end

            Value = Value - 0x2040810204080 + buffer.readu8(Buf, Cur + 7) * 0x2000000000000
            Next = Cur + 8
        until true

        return if not bit32.btest(Value, 1) then Value * 0.5 else (Value + 1) * -0.5, Next
    end

    Int[SER] = IntSer
    Int[DES] = IntDes
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
Types.Number = F32
Types.UInt = UInt
Types.Int = Int
Types.String = String
Types.String8 = String8
Types.String24 = String24
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
	const Ser = Schema[SER] :: Ser<T>
    const WriteBuffer = WriteBuffer
	const Cur = Ser(Value, WriteBuffer, 0)
	const Buf = CreateBuffer(Cur)
	CopyBuffer(Buf, 0, WriteBuffer, 0, Cur)
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
    const WriteBuffer = WriteBuffer
	const Cur = Ser(Value, WriteBuffer, 0)
	const Buf = CreateBuffer(Cur + Offset)
	CopyBuffer(Buf, Offset, WriteBuffer, 0, Cur)
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

--- Migrates the old serialized buffer based on the new provided SerdesNode.
---
--- Mainly designed for Struct types (but might sometimes work with other types).
--- @tag Core
--- @param Old SerdesNode<T> -- Old SerdesNode which was used to serialize the old buffer.
--- @param New SerdesNode<T> -- New SerdesNode which will be used to re-serialize the old buffer.
--- @param OldOffset number? -- Optional offset if old buffer was serialized with offset.
--- @param NewOffset number? -- Optional offset for the new buffer.
function VoidSentryUltimate.Migrate<T>(Old: SerdesNode<T>, New: SerdesNode<T>, OldBuf: buffer, OldOffset: number?, NewOffset: number?): buffer
    const OldDes = Old[DES] :: Des<T>
    const NewSer = New[SER] :: Ser<T>

    const Data = OldDes(OldBuf, OldOffset or 0)

    const WriteBuffer = WriteBuffer
    const Cur = NewSer(Data, WriteBuffer, NewOffset or 0)

    const Buf = CreateBuffer(Cur)
    CopyBuffer(Buf, 0, WriteBuffer, 0, Cur)
    return Buf
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
        local Cur = 0
        const Writes = Writes
        const Keys = Keys
        const WriteBuffer = WriteBuffer
        for i, Key in Keys do
            Cur = Writes[i](Data[Key], WriteBuffer, Cur)
        end
        const Buf = CreateBuffer(Cur)
        CopyBuffer(Buf, 0, WriteBuffer, 0, Cur)
        return Buf
    end

    function Object.SerializeWithOffset(Data: { [string]: any } & GetTypeFromTypeNodes<T>, Offset: number): buffer
        const Writes = Writes
        const Keys = Keys
        const WriteBuffer = WriteBuffer
        for i, Key in Keys do
            Offset = Writes[i](Data[Key], WriteBuffer, Offset)
        end
        const Buf = CreateBuffer(Offset)
        CopyBuffer(Buf, 0, WriteBuffer, 0, Offset)
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
        const Result = {}
        const Keys = Keys
        const Reads = Reads
        for i, Key in Keys do
            Result[Key], Offset = Reads[i](Buffer, Offset)
        end
        return Result :: GetTypeFromTypeNodes<T>, Offset
    end

    function Object.DeltaSerialize(Data: { [string]: any }, Offset: number?): buffer
        local Cur = Offset or 0
        const Start = Cur
        Cur += 1
        local Len = 0
        const WriteBuffer = WriteBuffer
        const KeyIndex = KeyIndex
        const Writes = Writes
        for Key, Value in Data do
            Len += 1
            const Index = KeyIndex[Key]
            buffer.writeu8(WriteBuffer, Cur, Index)
            Cur += 1
            Cur = Writes[Index](Value, WriteBuffer, Cur)
        end
        buffer.writeu8(WriteBuffer, Start, Len)
        const Buf = CreateBuffer(Cur)
        CopyBuffer(Buf, 0, WriteBuffer, 0, Cur)
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

    function Object.Migrate(OtherSchema: Schema<T & { [string]: SerdesNode<any> }>, OldBuf: buffer, OldOffset: number?, NewOffset: number?): buffer
        const Data = OtherSchema.DeserializeWithOffset(OldBuf, OldOffset or 0)

        const WriteBuffer = WriteBuffer
        local Cur = NewOffset or 0
        const Writes = Writes
        const Keys = Keys
        for i, Key in Keys do
            Cur = Writes[i](Data[Key], WriteBuffer, Cur)
        end

        const Buf = CreateBuffer(Cur)
        CopyBuffer(Buf, 0, WriteBuffer, 0, Cur)
        return Buf
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

TableFreeze(Types)
TableFreeze(VoidSentryUltimate)

return VoidSentryUltimate :: Lib

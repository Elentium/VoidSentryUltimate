--!native
--!optimize 2
--[[
    VoidSentryUltimate 
    [ V1.1.2 ]
    [ by IAMNOTULTRA3 a.k.a Elentium, Elite ]
    [ Apache-2.0 License ]

    Wally: "elentium/voidsentryultimate@1.1.2"
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
        -- number types
        read U8: SerdesNode<number>,
        read I8: SerdesNode<number>,
        read U16: SerdesNode<number>,
        read I16: SerdesNode<number>,
        read F16: SerdesNode<number>,
        read U24: SerdesNode<number>,
        read I24: SerdesNode<number>,
        read F24: SerdesNode<number>,
        read U32: SerdesNode<number>,
        read I32: SerdesNode<number>,
        read F32: SerdesNode<number>,
        read U40: SerdesNode<number>,
        read I40: SerdesNode<number>,
        read U48: SerdesNode<number>,
        read I48: SerdesNode<number>,
        read F64: SerdesNode<number>,
        read Number: SerdesNode<number>,
        read Int: SerdesNode<number>,
        read UInt: SerdesNode<number>,
        
        -- other primitives
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

        -- collection types
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

        -- roblox types
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
        read Enum8: <T>(EnumType: T & Enum) -> SerdesNode<GetEnumItem<T>>,
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
const Vector2New = Vector2.new

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
-- NUMBER TYPES
---------------------------------------------------------
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

---------------------------------------------------------
-- OTHER PRIMITIVES
---------------------------------------------------------

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

---------------------------------------------------------
-- COLLECTION TYPES
---------------------------------------------------------
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

---------------------------------------------------------
-- ROBLOX TYPES
---------------------------------------------------------

const Color3Node: SerdesNode<Color3> = {}
do
    const function Color3Ser(Value: Color3, Buf: buffer, Cur: number): number
        buffer.writeu8(Buf, Cur, Value.R * 255)
        buffer.writeu8(Buf, Cur + 1, Value.G * 255)
        buffer.writeu8(Buf, Cur + 2, Value.B * 255)
        return Cur + 3
    end

    const function Color3Des(Buf: buffer, Cur: number): (Color3, number)

        const r = buffer.readu8(Buf, Cur)
        const g = buffer.readu8(Buf, Cur + 1)
        const b = buffer.readu8(Buf, Cur + 2)
        return NewColor3(r, g, b), Cur + 3
    end

    Color3Node[SER] = Color3Ser
    Color3Node[DES] = Color3Des
end

const Color3Round: SerdesNode<Color3> = {}
do
    const function Color3RoundSer(Value: Color3, Buf: buffer, Cur: number): number
        buffer.writeu8(Buf, Cur, math.round(Value.R * 255))
        buffer.writeu8(Buf, Cur + 1, math.round(Value.G * 255))
        buffer.writeu8(Buf, Cur + 2, math.round(Value.B * 255))
        return Cur + 3
    end

    const function Color3RoundDes(Buf: buffer, Cur: number): (Color3, number)
        const r = buffer.readu8(Buf, Cur)
        const g = buffer.readu8(Buf, Cur + 1)
        const b = buffer.readu8(Buf, Cur + 2)
        return NewColor3(r, g, b), Cur + 3
    end

    Color3Round[SER] = Color3RoundSer
    Color3Round[DES] = Color3RoundDes
end

const Vector2Node: SerdesNode<Vector2> = {}
do
    const function Vector2Ser(Value: Vector2, Buf: buffer, Cur: number): number
        buffer.writef32(Buf, Cur, Value.X)
        buffer.writef32(Buf, Cur + 4, Value.Y)
        return Cur + 8
    end

    const function Vector2Des(Buf: buffer, Cur: number): (Vector2, number)
        const x = buffer.readf32(Buf, Cur)
        const y = buffer.readf32(Buf, Cur + 4)
        return Vector2New(x, y), Cur + 8
    end

    Vector2Node[SER] = Vector2Ser
    Vector2Node[DES] = Vector2Des
end

const Vector2F24: SerdesNode<Vector2> = {}
do
    const function Vector2F24Ser(Value: Vector2, Buf: buffer, Cur: number): number
        const FloatConverter = FloatConverter
        buffer.writef32(Buf, Cur + 2, Value.Y)
        buffer.writef32(FloatConverter, 0, Value.X)
        buffer.writeu16(Buf, Cur, buffer.readu16(FloatConverter, 1))
        buffer.writeu8(Buf, Cur + 2, buffer.readu8(FloatConverter, 3))
        return Cur + 6
    end

    const function Vector2F24Des(Buf: buffer, Cur: number): (Vector2, number)
        const Scale = F24Scale
        const Px = bit32.band(buffer.readu32(Buf, Cur), 0xFFFFFF)
        const x = bit32.bor(bit32.band(Px, 0x7FFF), 0x8000) * Scale[bit32.rshift(Px, 15) + 1]
        const Py = bit32.rshift(buffer.readu32(Buf, Cur + 2), 8)
        const y = bit32.bor(bit32.band(Py, 0x7FFF), 0x8000) * Scale[bit32.rshift(Py, 15) + 1]

        return Vector2New(x, y), Cur + 6
    end

    Vector2F24[SER] = Vector2F24Ser
    Vector2F24[DES] = Vector2F24Des
end

const Vector2F16: SerdesNode<Vector2> = {}
do
    const function Vector2F16Ser(Value: Vector2, Buf: buffer, Cur: number): number
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

        return Cur + 4
    end

    const function Vector2F16Des(Buf: buffer, Cur: number): (Vector2, number)
        const Scale = F16Scale
        const Px = buffer.readu16(Buf, Cur)
        const x = bit32.bor(bit32.band(Px, 0x3FF), 0x400) * Scale[bit32.rshift(Px, 10) + 1]
        const Py = buffer.readu16(Buf, Cur + 2)
        const y = bit32.bor(bit32.band(Py, 0x3FF), 0x400) * Scale[bit32.rshift(Py, 10) + 1]

        return Vector2New(x, y), Cur + 4
    end

    Vector2F16[SER] = Vector2F16Ser
    Vector2F16[DES] = Vector2F16Des
end

const Vector2U16: SerdesNode<Vector2> = {}
do
    const function Vector2U16Ser(Value: Vector2, Buf: buffer, Cur: number): number
        buffer.writeu16(Buf, Cur, Value.X)
        buffer.writeu16(Buf, Cur + 2, Value.Y)
        return Cur + 4
    end

    const function Vector2U16Des(Buf: buffer, Cur: number): (Vector2, number)
        const x = buffer.readu16(Buf, Cur)
        const y = buffer.readu16(Buf, Cur + 2)
        return Vector2New(x, y), Cur + 4
    end

    Vector2U16[SER] = Vector2U16Ser
    Vector2U16[DES] = Vector2U16Des
end

const Vector2I16: SerdesNode<Vector2> = {}
do
    const function Vector2I16Ser(Value: Vector2, Buf: buffer, Cur: number): number
        buffer.writei16(Buf, Cur, Value.X)
        buffer.writei16(Buf, Cur + 2, Value.Y)
        return Cur + 4
    end

    const function Vector2I16Des(Buf: buffer, Cur: number): (Vector2, number)
        const x = buffer.readi16(Buf, Cur)
        const y = buffer.readi16(Buf, Cur + 2)
        return Vector2New(x, y), Cur + 4
    end

    Vector2I16[SER] = Vector2I16Ser
    Vector2I16[DES] = Vector2I16Des
end

const Vector2U8: SerdesNode<Vector2> = {}
do
    const function Vector2U8Ser(Value: Vector2, Buf: buffer, Cur: number): number
        buffer.writeu8(Buf, Cur, Value.X)
        buffer.writeu8(Buf, Cur + 1, Value.Y)
        return Cur + 2
    end

    const function Vector2U8Des(Buf: buffer, Cur: number): (Vector2, number)
        const x = buffer.readu8(Buf, Cur)
        const y = buffer.readu8(Buf, Cur + 1)
        return Vector2New(x, y), Cur + 2
    end

    Vector2U8[SER] = Vector2U8Ser
    Vector2U8[DES] = Vector2U8Des
end

const Vector2I8: SerdesNode<Vector2> = {}
do
    const function Vector2I8Ser(Value: Vector2, Buf: buffer, Cur: number): number
        buffer.writei8(Buf, Cur, Value.X)
        buffer.writei8(Buf, Cur + 1, Value.Y)
        return Cur + 2
    end

    const function Vector2I8Des(Buf: buffer, Cur: number): (Vector2, number)
        const x = buffer.readi8(Buf, Cur)
        const y = buffer.readi8(Buf, Cur + 1)
        return Vector2New(x, y), Cur + 2
    end

    Vector2I8[SER] = Vector2I8Ser
    Vector2I8[DES] = Vector2I8Des
end

const Vector2U24: SerdesNode<Vector2> = {}
do
    const function Vector2U24Ser(Value: Vector2, Buf: buffer, Cur: number): number
        buffer.writeu32(Buf, Cur, Value.X)
        const y = Value.Y
        buffer.writeu16(Buf, Cur + 3, y)
        buffer.writeu8(Buf, Cur + 5, bit32.rshift(y, 16))
        return Cur + 6
    end

    const function Vector2U24Des(Buf: buffer, Cur: number): (Vector2, number)
        const x = bit32.band(buffer.readu32(Buf, Cur), 0xFFFFFF)
        const y = bit32.rshift(buffer.readu32(Buf, Cur + 2), 8)
        return Vector2New(x, y), Cur + 6
    end

    Vector2U24[SER] = Vector2U24Ser
    Vector2U24[DES] = Vector2U24Des
end

const Vector2I24: SerdesNode<Vector2> = {}
do
    const function Vector2I24Ser(Value: Vector2, Buf: buffer, Cur: number): number
        buffer.writeu32(Buf, Cur, Value.X)
        const y = Value.Y
        buffer.writeu16(Buf, Cur + 3, y)
        buffer.writeu8(Buf, Cur + 5, bit32.rshift(y, 16))
        return Cur + 6
    end

    const function Vector2I24Des(Buf: buffer, Cur: number): (Vector2, number)
        const x = buffer.readu16(Buf, Cur) + buffer.readi8(Buf, Cur + 2) * 65536
        const y = buffer.readi32(Buf, Cur + 2) // 256
        return Vector2New(x, y), Cur + 6
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
        return Cur + 16
    end

    const function UDim2Des(Buf: buffer, Cur: number): (UDim2, number)
        const xScale = buffer.readf32(Buf, Cur)
        const xOffset = buffer.readf32(Buf, Cur + 4)
        const yScale = buffer.readf32(Buf, Cur + 8)
        const yOffset = buffer.readf32(Buf, Cur + 12)
        return NewUDim2(xScale, xOffset, yScale, yOffset), Cur + 16
    end

    UDim2Node[SER] = UDim2Ser
    UDim2Node[DES] = UDim2Des
end

const UDim2Scale: SerdesNode<UDim2> = {}
do
    const function UDim2ScaleSer(Value: UDim2, Buf: buffer, Cur: number): number
        buffer.writef32(Buf, Cur, Value.X.Scale)
        buffer.writef32(Buf, Cur + 4, Value.Y.Scale)
        return Cur + 8
    end

    const function UDim2ScaleDes(Buf: buffer, Cur: number): (UDim2, number)
        const xScale = buffer.readf32(Buf, Cur)
        const yScale = buffer.readf32(Buf, Cur + 4)
        return FromUDim2Scale(xScale, yScale), Cur + 8
    end

    UDim2Scale[SER] = UDim2ScaleSer
    UDim2Scale[DES] = UDim2ScaleDes
end

const UDim2Offset: SerdesNode<UDim2> = {}
do
    const function UDim2OffsetSer(Value: UDim2, Buf: buffer, Cur: number): number
        buffer.writef32(Buf, Cur, Value.X.Offset)
        buffer.writef32(Buf, Cur + 4, Value.Y.Offset)
        return Cur + 8
    end

    const function UDim2OffsetDes(Buf: buffer, Cur: number): (UDim2, number)
        const xOffset = buffer.readf32(Buf, Cur)
        const yOffset = buffer.readf32(Buf, Cur + 4)
        return FromUDim2Offset(xOffset, yOffset), Cur + 8
    end

    UDim2Offset[SER] = UDim2OffsetSer
    UDim2Offset[DES] = UDim2OffsetDes
end

const UDim2OffsetI16: SerdesNode<UDim2> = {}
do
    const function UDim2OffsetI16Ser(Value: UDim2, Buf: buffer, Cur: number): number
        buffer.writei16(Buf, Cur, Value.X.Offset)
        buffer.writei16(Buf, Cur + 2, Value.Y.Offset)
        return Cur + 4
    end

    const function UDim2OffsetI16Des(Buf: buffer, Cur: number): (UDim2, number)
        const xOffset = buffer.readi16(Buf, Cur)
        const yOffset = buffer.readi16(Buf, Cur + 2)
        return FromUDim2Offset(xOffset, yOffset), Cur + 4
    end

    UDim2OffsetI16[SER] = UDim2OffsetI16Ser
    UDim2OffsetI16[DES] = UDim2OffsetI16Des
end

const UDim2ScaleF24: SerdesNode<UDim2> = {}
do
    const function UDim2ScaleF24Ser(Value: UDim2, Buf: buffer, Cur: number): number
        const FloatConverter = FloatConverter
        buffer.writef32(Buf, Cur + 2, Value.Y.Scale)
        buffer.writef32(FloatConverter, 0, Value.X.Scale)
        buffer.writeu16(Buf, Cur, buffer.readu16(FloatConverter, 1))
        buffer.writeu8(Buf, Cur + 2, buffer.readu8(FloatConverter, 3))
        return Cur + 6
    end

    const function UDim2ScaleF24Des(Buf: buffer, Cur: number): (UDim2, number)
        const Scale = F24Scale
        const PxScale = bit32.band(buffer.readu32(Buf, Cur), 0xFFFFFF)
        const xScale = bit32.bor(bit32.band(PxScale, 0x7FFF), 0x8000) * Scale[bit32.rshift(PxScale, 15) + 1]
        const PyScale = bit32.rshift(buffer.readu32(Buf, Cur + 2), 8)
        const yScale = bit32.bor(bit32.band(PyScale, 0x7FFF), 0x8000) * Scale[bit32.rshift(PyScale, 15) + 1]
        return FromUDim2Scale(xScale, yScale), Cur + 6
    end

    UDim2ScaleF24[SER] = UDim2ScaleF24Ser
    UDim2ScaleF24[DES] = UDim2ScaleF24Des
end

const InstanceNode: SerdesNode<Instance> = {}
do
    const function InstanceSer(Value: Instance, Buf: buffer, Cur: number): number
        const Id = InstanceMap[Value]
        if Id then
            buffer.writeu16(Buf, Cur, Id)
            return Cur + 2
        end

        error(`Instance {Value:GetFullName()} not found in InstanceMap, make sure INSTANCE_SERIALIZATION_ENABLED is set to true`)
    end

    const function InstanceDes(Buf: buffer, Cur: number): (Instance, number)
        const Id = buffer.readu16(Buf, Cur)
        const Value = IdMap[Id]
        if not Value then -- lowk wanted to remove this check for another micro perf gain but this error could be useful for debugging
            error(`Instance not found by id {Id}, make sure INSTANCE_SERIALIZATION_ENABLED is set to true and the Instance is reachable by this context.`)
        end

        return Value, Cur + 2
    end

    InstanceNode[SER] = InstanceSer
    InstanceNode[DES] = InstanceDes
end

const Instance24: SerdesNode<Instance> = {}
do
    const function Instance24Ser(Value: Instance, Buf: buffer, Cur: number): number
        const Id = InstanceMap[Value]
        if Id then
            buffer.writeu16(Buf, Cur, Id)
            buffer.writeu8(Buf, Cur + 2, bit32.rshift(Id, 16))
            return Cur + 3
        end

        error(`Instance {Value:GetFullName()} not found in InstanceMap, make sure INSTANCE_SERIALIZATION_ENABLED is set to true`)
    end

    const function Instance24Des(Buf: buffer, Cur: number): (Instance, number)
        const Id = buffer.readu16(Buf, Cur) + buffer.readu8(Buf, Cur + 2) * 65536
        const Value = IdMap[Id]
        if not Value then
            error(`Instance not found by id {Id}, make sure INSTANCE_SERIALIZATION_ENABLED is set to true and the Instance is reachable by this context.`)
        end

        return Value, Cur + 2
    end

    Instance24[SER] = Instance24Ser
    Instance24[DES] = Instance24Des
end

const CFrameNode: SerdesNode<CFrame> = {}
do
    const function CFrameSer(Value: CFrame, Buf: buffer, Cur: number): number
        const 
        x, y, z, 
        R0, R01, R02, 
        R10, R11, R12, 
        R20, R21, R22 
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
    
        return Cur + 48
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

        return NewCFrame(x, y, z, R0, R01, R02, R10, R11, R12, R20, R21, R22), Cur + 48
    end

    CFrameNode[SER] = CFrameSer
    CFrameNode[DES] = CFrameDes
end

const Quant8Angle = CreateTable(256, 0)
for i = 0, 255 do
    Quant8Angle[i + 1] = (i / 255) * DoublePi - Pi
end

const CFrameQuant8: SerdesNode<CFrame> = {}
do
    const function CFrameQuant8Ser(Value: CFrame, Buf: buffer, Cur: number): number
        const Pos = Value.Position

        buffer.writef32(Buf, Cur, Pos.X)
        buffer.writef32(Buf, Cur + 4, Pos.Y)
        buffer.writef32(Buf, Cur + 8, Pos.Z)

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

        const Angles = Quant8Angle
        const ry = Angles[buffer.readu8(Buf, Cur + 12) + 1]
        const rx = Angles[buffer.readu8(Buf, Cur + 13) + 1] * 0.5
        const rz = Angles[buffer.readu8(Buf, Cur + 14) + 1]

        return NewCFrameFromOrientation(rx, ry, rz) + Vector3.new(x, y, z), Cur + 15
    end

    CFrameQuant8[SER] = CFrameQuant8Ser
    CFrameQuant8[DES] = CFrameQuant8Des
end

const CFrameQuant8F16: SerdesNode<CFrame> = {}
do
    const function CFrameQuant8F16Ser(Value: CFrame, Buf: buffer, Cur: number): number
        const Pos = Value.Position

        const FloatConverter = FloatConverter

        do
            buffer.writef32(FloatConverter, 0, Pos.X)
            const Bits = buffer.readu32(FloatConverter, 0)
            const Sign = bit32.band(bit32.rshift(Bits, 16), 0x8000)
            const Abs = bit32.band(Bits, 0x7FFFFFFF) + 0x1000
            buffer.writeu16(Buf, Cur, if Abs >= 0x47800000 then Sign + 0x7BFF elseif Abs < 0x38800000 then Sign else Sign + bit32.rshift(Abs, 13) - 0x1C000)
        end
        do
            buffer.writef32(FloatConverter, 0, Pos.Y)
            const Bits = buffer.readu32(FloatConverter, 0)
            const Sign = bit32.band(bit32.rshift(Bits, 16), 0x8000)
            const Abs = bit32.band(Bits, 0x7FFFFFFF) + 0x1000
            buffer.writeu16(Buf, Cur + 2, if Abs >= 0x47800000 then Sign + 0x7BFF elseif Abs < 0x38800000 then Sign else Sign + bit32.rshift(Abs, 13) - 0x1C000)
        end
        do
            buffer.writef32(FloatConverter, 0, Pos.Z)
            const Bits = buffer.readu32(FloatConverter, 0)
            const Sign = bit32.band(bit32.rshift(Bits, 16), 0x8000)
            const Abs = bit32.band(Bits, 0x7FFFFFFF) + 0x1000
            buffer.writeu16(Buf, Cur + 4, if Abs >= 0x47800000 then Sign + 0x7BFF elseif Abs < 0x38800000 then Sign else Sign + bit32.rshift(Abs, 13) - 0x1C000)
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
        const Scale = F16Scale
        const Px = buffer.readu16(Buf, Cur)
        const x = bit32.bor(bit32.band(Px, 0x3FF), 0x400) * Scale[bit32.rshift(Px, 10) + 1]
        const Py = buffer.readu16(Buf, Cur + 2)
        const y = bit32.bor(bit32.band(Py, 0x3FF), 0x400) * Scale[bit32.rshift(Py, 10) + 1]
        const Pz = buffer.readu16(Buf, Cur + 4)
        const z = bit32.bor(bit32.band(Pz, 0x3FF), 0x400) * Scale[bit32.rshift(Pz, 10) + 1]

        const Angles = Quant8Angle
        const ry = Angles[buffer.readu8(Buf, Cur + 6) + 1]
        const rx = Angles[buffer.readu8(Buf, Cur + 7) + 1] * 0.5
        const rz = Angles[buffer.readu8(Buf, Cur + 8) + 1]

        return NewCFrameFromOrientation(rx, ry, rz) + Vector3.new(x, y, z), Cur + 9
    end

    CFrameQuant8F16[SER] = CFrameQuant8F16Ser
    CFrameQuant8F16[DES] = CFrameQuant8F16Des
end

const CFrameQuant: SerdesNode<CFrame> = {}
do
    const function CFrameQuantSer(Value: CFrame, Buf: buffer, Cur: number): number
        const Pos = Value.Position

        buffer.writef32(Buf, Cur, Pos.X)
        buffer.writef32(Buf, Cur + 4, Pos.Y)
        buffer.writef32(Buf, Cur + 8, Pos.Z)

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

        return NewCFrameFromOrientation(rx, ry, rz) + Vector3.new(x, y, z), Cur + 18
    end

    CFrameQuant[SER] = CFrameQuantSer
    CFrameQuant[DES] = CFrameQuantDes
end

const CFrameQuantF16: SerdesNode<CFrame> = {}
do
    const function CFrameQuantF16Ser(Value: CFrame, Buf: buffer, Cur: number): number
        const Pos = Value.Position

        const FloatConverter = FloatConverter

        do
            buffer.writef32(FloatConverter, 0, Pos.X)
            const Bits = buffer.readu32(FloatConverter, 0)
            const Sign = bit32.band(bit32.rshift(Bits, 16), 0x8000)
            const Abs = bit32.band(Bits, 0x7FFFFFFF) + 0x1000
            buffer.writeu16(Buf, Cur, if Abs >= 0x47800000 then Sign + 0x7BFF elseif Abs < 0x38800000 then Sign else Sign + bit32.rshift(Abs, 13) - 0x1C000)
        end
        do
            buffer.writef32(FloatConverter, 0, Pos.Y)
            const Bits = buffer.readu32(FloatConverter, 0)
            const Sign = bit32.band(bit32.rshift(Bits, 16), 0x8000)
            const Abs = bit32.band(Bits, 0x7FFFFFFF) + 0x1000
            buffer.writeu16(Buf, Cur + 2, if Abs >= 0x47800000 then Sign + 0x7BFF elseif Abs < 0x38800000 then Sign else Sign + bit32.rshift(Abs, 13) - 0x1C000)
        end
        do
            buffer.writef32(FloatConverter, 0, Pos.Z)
            const Bits = buffer.readu32(FloatConverter, 0)
            const Sign = bit32.band(bit32.rshift(Bits, 16), 0x8000)
            const Abs = bit32.band(Bits, 0x7FFFFFFF) + 0x1000
            buffer.writeu16(Buf, Cur + 4, if Abs >= 0x47800000 then Sign + 0x7BFF elseif Abs < 0x38800000 then Sign else Sign + bit32.rshift(Abs, 13) - 0x1C000)
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
        const Scale = F16Scale
        const Px = buffer.readu16(Buf, Cur)
        const x = bit32.bor(bit32.band(Px, 0x3FF), 0x400) * Scale[bit32.rshift(Px, 10) + 1]
        const Py = buffer.readu16(Buf, Cur + 2)
        const y = bit32.bor(bit32.band(Py, 0x3FF), 0x400) * Scale[bit32.rshift(Py, 10) + 1]
        const Pz = buffer.readu16(Buf, Cur + 4)
        const z = bit32.bor(bit32.band(Pz, 0x3FF), 0x400) * Scale[bit32.rshift(Pz, 10) + 1]
        const Yaw = buffer.readu16(Buf, Cur + 6)
        const Pitch = buffer.readu16(Buf, Cur + 8)
        const Roll = buffer.readu16(Buf, Cur + 10)

        const ry = (Yaw / 65535) * DoublePi - Pi
        const rx = (Pitch / 65535) * Pi - HalfPi
        const rz = (Roll / 65535) * DoublePi - Pi

        return NewCFrameFromOrientation(rx, ry, rz) + Vector3.new(x, y, z), Cur + 12
    end

    CFrameQuantF16[SER] = CFrameQuantF16Ser
    CFrameQuantF16[DES] = CFrameQuantF16Des
end

const QCFrame: SerdesNode<CFrame> = {}
do
    const function QCFrameSer(Value: CFrame, Buf: buffer, Cur: number): number
        const
        x, y, z,
        R00, R01, R02,
        R10, R11, R12,
        R20, R21, R22
        = Value:GetComponents()

        local qx, qy, qz, qw
        const Trace = R00 + R11 + R22
        if Trace > 0 then
            const S = math.sqrt(Trace + 1) * 2
            qx, qy, qz, qw = (R21 - R12) / S, (R02 - R20) / S, (R10 - R01) / S, S * 0.25
        elseif R00 > R11 and R00 > R22 then
            const S = math.sqrt(1 + R00 - R11 - R22) * 2
            qx, qy, qz, qw = S * 0.25, (R01 + R10) / S, (R02 + R20) / S, (R21 - R12) / S
        elseif R11 > R22 then
            const S = math.sqrt(1 + R11 - R00 - R22) * 2
            qx, qy, qz, qw = (R01 + R10) / S, S * 0.25, (R12 + R21) / S, (R02 - R20) / S
        else
            const S = math.sqrt(1 + R22 - R00 - R11) * 2
            qx, qy, qz, qw = (R02 + R20) / S, (R12 + R21) / S, S * 0.25, (R10 - R01) / S
        end

        buffer.writef32(Buf, Cur, x)
        buffer.writef32(Buf, Cur + 4, y)
        buffer.writef32(Buf, Cur + 8, z)
        buffer.writef32(Buf, Cur + 12, qx)
        buffer.writef32(Buf, Cur + 16, qy)
        buffer.writef32(Buf, Cur + 20, qz)
        buffer.writef32(Buf, Cur + 24, qw)

        return Cur + 28
    end

    const function QCFrameDes(Buf: buffer, Cur: number): (CFrame, number)
        const x = buffer.readf32(Buf, Cur)
        const y = buffer.readf32(Buf, Cur + 4)
        const z = buffer.readf32(Buf, Cur + 8)
        const qx = buffer.readf32(Buf, Cur + 12)
        const qy = buffer.readf32(Buf, Cur + 16)
        const qz = buffer.readf32(Buf, Cur + 20)
        const qw = buffer.readf32(Buf, Cur + 24)

        return NewCFrame(x, y, z, qx, qy, qz, qw), Cur + 28
    end

    QCFrame[SER] = QCFrameSer
    QCFrame[DES] = QCFrameDes
end

const CFrameF24: SerdesNode<CFrame> = {}
do
    const function CFrameF24Ser(Value: CFrame, Buf: buffer, Cur: number): number
        const
        x, y, z,
        R00, R01, R02,
        R10, R11, R12,
        R20, R21, R22
        = Value:GetComponents()

        const FloatConverter = FloatConverter

        buffer.writef32(Buf, Cur + 32, R22)
        buffer.writef32(Buf, Cur + 29, R21)
        buffer.writef32(Buf, Cur + 26, R20)
        buffer.writef32(Buf, Cur + 23, R12)
        buffer.writef32(Buf, Cur + 20, R11)
        buffer.writef32(Buf, Cur + 17, R10)
        buffer.writef32(Buf, Cur + 14, R02)
        buffer.writef32(Buf, Cur + 11, R01)
        buffer.writef32(Buf, Cur + 8, R00)
        buffer.writef32(Buf, Cur + 5, z)
        buffer.writef32(Buf, Cur + 2, y)
        buffer.writef32(FloatConverter, 0, x)
        buffer.writeu16(Buf, Cur, buffer.readu16(FloatConverter, 1))
        buffer.writeu8(Buf, Cur + 2, buffer.readu8(FloatConverter, 3))

        return Cur + 36
    end

    const function CFrameF24Des(Buf: buffer, Cur: number): (CFrame, number)
        const Scale = F24Scale
        const Px = bit32.band(buffer.readu32(Buf, Cur), 0xFFFFFF)
        const x = bit32.bor(bit32.band(Px, 0x7FFF), 0x8000) * Scale[bit32.rshift(Px, 15) + 1]
        const Py = bit32.rshift(buffer.readu32(Buf, Cur + 2), 8)
        const y = bit32.bor(bit32.band(Py, 0x7FFF), 0x8000) * Scale[bit32.rshift(Py, 15) + 1]
        const Pz = bit32.rshift(buffer.readu32(Buf, Cur + 5), 8)
        const z = bit32.bor(bit32.band(Pz, 0x7FFF), 0x8000) * Scale[bit32.rshift(Pz, 15) + 1]
        const PR00 = bit32.rshift(buffer.readu32(Buf, Cur + 8), 8)
        const R00 = bit32.bor(bit32.band(PR00, 0x7FFF), 0x8000) * Scale[bit32.rshift(PR00, 15) + 1]
        const PR01 = bit32.rshift(buffer.readu32(Buf, Cur + 11), 8)
        const R01 = bit32.bor(bit32.band(PR01, 0x7FFF), 0x8000) * Scale[bit32.rshift(PR01, 15) + 1]
        const PR02 = bit32.rshift(buffer.readu32(Buf, Cur + 14), 8)
        const R02 = bit32.bor(bit32.band(PR02, 0x7FFF), 0x8000) * Scale[bit32.rshift(PR02, 15) + 1]
        const PR10 = bit32.rshift(buffer.readu32(Buf, Cur + 17), 8)
        const R10 = bit32.bor(bit32.band(PR10, 0x7FFF), 0x8000) * Scale[bit32.rshift(PR10, 15) + 1]
        const PR11 = bit32.rshift(buffer.readu32(Buf, Cur + 20), 8)
        const R11 = bit32.bor(bit32.band(PR11, 0x7FFF), 0x8000) * Scale[bit32.rshift(PR11, 15) + 1]
        const PR12 = bit32.rshift(buffer.readu32(Buf, Cur + 23), 8)
        const R12 = bit32.bor(bit32.band(PR12, 0x7FFF), 0x8000) * Scale[bit32.rshift(PR12, 15) + 1]
        const PR20 = bit32.rshift(buffer.readu32(Buf, Cur + 26), 8)
        const R20 = bit32.bor(bit32.band(PR20, 0x7FFF), 0x8000) * Scale[bit32.rshift(PR20, 15) + 1]
        const PR21 = bit32.rshift(buffer.readu32(Buf, Cur + 29), 8)
        const R21 = bit32.bor(bit32.band(PR21, 0x7FFF), 0x8000) * Scale[bit32.rshift(PR21, 15) + 1]
        const PR22 = bit32.rshift(buffer.readu32(Buf, Cur + 32), 8)
        const R22 = bit32.bor(bit32.band(PR22, 0x7FFF), 0x8000) * Scale[bit32.rshift(PR22, 15) + 1]

        return NewCFrame(x, y, z, R00, R01, R02, R10, R11, R12, R20, R21, R22), Cur + 36
    end

    CFrameF24[SER] = CFrameF24Ser
    CFrameF24[DES] = CFrameF24Des
end

const CFrameF16: SerdesNode<CFrame> = {}
do
    const function CFrameF16Ser(Value: CFrame, Buf: buffer, Cur: number): number
        const
        x, y, z,
        R00, R01, R02,
        R10, R11, R12,
        R20, R21, R22
        = Value:GetComponents()

        const FloatConverter = FloatConverter

        do
            buffer.writef32(FloatConverter, 0, x)
            const Bits = buffer.readu32(FloatConverter, 0)
            const Sign = bit32.band(bit32.rshift(Bits, 16), 0x8000)
            const Abs = bit32.band(Bits, 0x7FFFFFFF) + 0x1000
            buffer.writeu16(Buf, Cur, if Abs >= 0x47800000 then Sign + 0x7BFF elseif Abs < 0x38800000 then Sign else Sign + bit32.rshift(Abs, 13) - 0x1C000)
        end
        do
            buffer.writef32(FloatConverter, 0, y)
            const Bits = buffer.readu32(FloatConverter, 0)
            const Sign = bit32.band(bit32.rshift(Bits, 16), 0x8000)
            const Abs = bit32.band(Bits, 0x7FFFFFFF) + 0x1000
            buffer.writeu16(Buf, Cur + 2, if Abs >= 0x47800000 then Sign + 0x7BFF elseif Abs < 0x38800000 then Sign else Sign + bit32.rshift(Abs, 13) - 0x1C000)
        end
        do
            buffer.writef32(FloatConverter, 0, z)
            const Bits = buffer.readu32(FloatConverter, 0)
            const Sign = bit32.band(bit32.rshift(Bits, 16), 0x8000)
            const Abs = bit32.band(Bits, 0x7FFFFFFF) + 0x1000
            buffer.writeu16(Buf, Cur + 4, if Abs >= 0x47800000 then Sign + 0x7BFF elseif Abs < 0x38800000 then Sign else Sign + bit32.rshift(Abs, 13) - 0x1C000)
        end
        do
            buffer.writef32(FloatConverter, 0, R00)
            const Bits = buffer.readu32(FloatConverter, 0)
            const Sign = bit32.band(bit32.rshift(Bits, 16), 0x8000)
            const Abs = bit32.band(Bits, 0x7FFFFFFF) + 0x1000
            buffer.writeu16(Buf, Cur + 6, if Abs >= 0x47800000 then Sign + 0x7BFF elseif Abs < 0x38800000 then Sign else Sign + bit32.rshift(Abs, 13) - 0x1C000)
        end
        do
            buffer.writef32(FloatConverter, 0, R01)
            const Bits = buffer.readu32(FloatConverter, 0)
            const Sign = bit32.band(bit32.rshift(Bits, 16), 0x8000)
            const Abs = bit32.band(Bits, 0x7FFFFFFF) + 0x1000
            buffer.writeu16(Buf, Cur + 8, if Abs >= 0x47800000 then Sign + 0x7BFF elseif Abs < 0x38800000 then Sign else Sign + bit32.rshift(Abs, 13) - 0x1C000)
        end
        do
            buffer.writef32(FloatConverter, 0, R02)
            const Bits = buffer.readu32(FloatConverter, 0)
            const Sign = bit32.band(bit32.rshift(Bits, 16), 0x8000)
            const Abs = bit32.band(Bits, 0x7FFFFFFF) + 0x1000
            buffer.writeu16(Buf, Cur + 10, if Abs >= 0x47800000 then Sign + 0x7BFF elseif Abs < 0x38800000 then Sign else Sign + bit32.rshift(Abs, 13) - 0x1C000)
        end
        do
            buffer.writef32(FloatConverter, 0, R10)
            const Bits = buffer.readu32(FloatConverter, 0)
            const Sign = bit32.band(bit32.rshift(Bits, 16), 0x8000)
            const Abs = bit32.band(Bits, 0x7FFFFFFF) + 0x1000
            buffer.writeu16(Buf, Cur + 12, if Abs >= 0x47800000 then Sign + 0x7BFF elseif Abs < 0x38800000 then Sign else Sign + bit32.rshift(Abs, 13) - 0x1C000)
        end
        do
            buffer.writef32(FloatConverter, 0, R11)
            const Bits = buffer.readu32(FloatConverter, 0)
            const Sign = bit32.band(bit32.rshift(Bits, 16), 0x8000)
            const Abs = bit32.band(Bits, 0x7FFFFFFF) + 0x1000
            buffer.writeu16(Buf, Cur + 14, if Abs >= 0x47800000 then Sign + 0x7BFF elseif Abs < 0x38800000 then Sign else Sign + bit32.rshift(Abs, 13) - 0x1C000)
        end
        do
            buffer.writef32(FloatConverter, 0, R12)
            const Bits = buffer.readu32(FloatConverter, 0)
            const Sign = bit32.band(bit32.rshift(Bits, 16), 0x8000)
            const Abs = bit32.band(Bits, 0x7FFFFFFF) + 0x1000
            buffer.writeu16(Buf, Cur + 16, if Abs >= 0x47800000 then Sign + 0x7BFF elseif Abs < 0x38800000 then Sign else Sign + bit32.rshift(Abs, 13) - 0x1C000)
        end
        do
            buffer.writef32(FloatConverter, 0, R20)
            const Bits = buffer.readu32(FloatConverter, 0)
            const Sign = bit32.band(bit32.rshift(Bits, 16), 0x8000)
            const Abs = bit32.band(Bits, 0x7FFFFFFF) + 0x1000
            buffer.writeu16(Buf, Cur + 18, if Abs >= 0x47800000 then Sign + 0x7BFF elseif Abs < 0x38800000 then Sign else Sign + bit32.rshift(Abs, 13) - 0x1C000)
        end
        do
            buffer.writef32(FloatConverter, 0, R21)
            const Bits = buffer.readu32(FloatConverter, 0)
            const Sign = bit32.band(bit32.rshift(Bits, 16), 0x8000)
            const Abs = bit32.band(Bits, 0x7FFFFFFF) + 0x1000
            buffer.writeu16(Buf, Cur + 20, if Abs >= 0x47800000 then Sign + 0x7BFF elseif Abs < 0x38800000 then Sign else Sign + bit32.rshift(Abs, 13) - 0x1C000)
        end
        do
            buffer.writef32(FloatConverter, 0, R22)
            const Bits = buffer.readu32(FloatConverter, 0)
            const Sign = bit32.band(bit32.rshift(Bits, 16), 0x8000)
            const Abs = bit32.band(Bits, 0x7FFFFFFF) + 0x1000
            buffer.writeu16(Buf, Cur + 22, if Abs >= 0x47800000 then Sign + 0x7BFF elseif Abs < 0x38800000 then Sign else Sign + bit32.rshift(Abs, 13) - 0x1C000)
        end

        return Cur + 24
    end

    const function CFrameF16Des(Buf: buffer, Cur: number): (CFrame, number)
        const Scale = F16Scale
        const Px = buffer.readu16(Buf, Cur)
        const x = bit32.bor(bit32.band(Px, 0x3FF), 0x400) * Scale[bit32.rshift(Px, 10) + 1]
        const Py = buffer.readu16(Buf, Cur + 2)
        const y = bit32.bor(bit32.band(Py, 0x3FF), 0x400) * Scale[bit32.rshift(Py, 10) + 1]
        const Pz = buffer.readu16(Buf, Cur + 4)
        const z = bit32.bor(bit32.band(Pz, 0x3FF), 0x400) * Scale[bit32.rshift(Pz, 10) + 1]
        const PR00 = buffer.readu16(Buf, Cur + 6)
        const R00 = bit32.bor(bit32.band(PR00, 0x3FF), 0x400) * Scale[bit32.rshift(PR00, 10) + 1]
        const PR01 = buffer.readu16(Buf, Cur + 8)
        const R01 = bit32.bor(bit32.band(PR01, 0x3FF), 0x400) * Scale[bit32.rshift(PR01, 10) + 1]
        const PR02 = buffer.readu16(Buf, Cur + 10)
        const R02 = bit32.bor(bit32.band(PR02, 0x3FF), 0x400) * Scale[bit32.rshift(PR02, 10) + 1]
        const PR10 = buffer.readu16(Buf, Cur + 12)
        const R10 = bit32.bor(bit32.band(PR10, 0x3FF), 0x400) * Scale[bit32.rshift(PR10, 10) + 1]
        const PR11 = buffer.readu16(Buf, Cur + 14)
        const R11 = bit32.bor(bit32.band(PR11, 0x3FF), 0x400) * Scale[bit32.rshift(PR11, 10) + 1]
        const PR12 = buffer.readu16(Buf, Cur + 16)
        const R12 = bit32.bor(bit32.band(PR12, 0x3FF), 0x400) * Scale[bit32.rshift(PR12, 10) + 1]
        const PR20 = buffer.readu16(Buf, Cur + 18)
        const R20 = bit32.bor(bit32.band(PR20, 0x3FF), 0x400) * Scale[bit32.rshift(PR20, 10) + 1]
        const PR21 = buffer.readu16(Buf, Cur + 20)
        const R21 = bit32.bor(bit32.band(PR21, 0x3FF), 0x400) * Scale[bit32.rshift(PR21, 10) + 1]
        const PR22 = buffer.readu16(Buf, Cur + 22)
        const R22 = bit32.bor(bit32.band(PR22, 0x3FF), 0x400) * Scale[bit32.rshift(PR22, 10) + 1]

        return NewCFrame(x, y, z, R00, R01, R02, R10, R11, R12, R20, R21, R22), Cur + 24
    end

    CFrameF16[SER] = CFrameF16Ser
    CFrameF16[DES] = CFrameF16Des
end

const QCFrameF24: SerdesNode<CFrame> = {}
do
    const function QCFrameF24Ser(Value: CFrame, Buf: buffer, Cur: number): number
        const
        x, y, z,
        R00, R01, R02,
        R10, R11, R12,
        R20, R21, R22
        = Value:GetComponents()

        local qx: number, qy: number, qz: number, qw: number
        const Trace = R00 + R11 + R22
        if Trace > 0 then
            const S = math.sqrt(Trace + 1) * 2
            qx, qy, qz, qw = (R21 - R12) / S, (R02 - R20) / S, (R10 - R01) / S, S * 0.25
        elseif R00 > R11 and R00 > R22 then
            const S = math.sqrt(1 + R00 - R11 - R22) * 2
            qx, qy, qz, qw = S * 0.25, (R01 + R10) / S, (R02 + R20) / S, (R21 - R12) / S
        elseif R11 > R22 then
            const S = math.sqrt(1 + R11 - R00 - R22) * 2
            qx, qy, qz, qw = (R01 + R10) / S, S * 0.25, (R12 + R21) / S, (R02 - R20) / S
        else
            const S = math.sqrt(1 + R22 - R00 - R11) * 2
            qx, qy, qz, qw = (R02 + R20) / S, (R12 + R21) / S, S * 0.25, (R10 - R01) / S
        end

        const FloatConverter = FloatConverter

        buffer.writef32(Buf, Cur + 17, qw)
        buffer.writef32(Buf, Cur + 14, qz)
        buffer.writef32(Buf, Cur + 11, qy)
        buffer.writef32(Buf, Cur + 8, qx)
        buffer.writef32(Buf, Cur + 5, z)
        buffer.writef32(Buf, Cur + 2, y)
        buffer.writef32(FloatConverter, 0, x)
        buffer.writeu16(Buf, Cur, buffer.readu16(FloatConverter, 1))
        buffer.writeu8(Buf, Cur + 2, buffer.readu8(FloatConverter, 3))

        return Cur + 21
    end

    const function QCFrameF24Des(Buf: buffer, Cur: number): (CFrame, number)
        const Scale = F24Scale
        const Px = bit32.band(buffer.readu32(Buf, Cur), 0xFFFFFF)
        const x = bit32.bor(bit32.band(Px, 0x7FFF), 0x8000) * Scale[bit32.rshift(Px, 15) + 1]
        const Py = bit32.rshift(buffer.readu32(Buf, Cur + 2), 8)
        const y = bit32.bor(bit32.band(Py, 0x7FFF), 0x8000) * Scale[bit32.rshift(Py, 15) + 1]
        const Pz = bit32.rshift(buffer.readu32(Buf, Cur + 5), 8)
        const z = bit32.bor(bit32.band(Pz, 0x7FFF), 0x8000) * Scale[bit32.rshift(Pz, 15) + 1]
        const Pqx = bit32.rshift(buffer.readu32(Buf, Cur + 8), 8)
        const qx = bit32.bor(bit32.band(Pqx, 0x7FFF), 0x8000) * Scale[bit32.rshift(Pqx, 15) + 1]
        const Pqy = bit32.rshift(buffer.readu32(Buf, Cur + 11), 8)
        const qy = bit32.bor(bit32.band(Pqy, 0x7FFF), 0x8000) * Scale[bit32.rshift(Pqy, 15) + 1]
        const Pqz = bit32.rshift(buffer.readu32(Buf, Cur + 14), 8)
        const qz = bit32.bor(bit32.band(Pqz, 0x7FFF), 0x8000) * Scale[bit32.rshift(Pqz, 15) + 1]
        const Pqw = bit32.rshift(buffer.readu32(Buf, Cur + 17), 8)
        const qw = bit32.bor(bit32.band(Pqw, 0x7FFF), 0x8000) * Scale[bit32.rshift(Pqw, 15) + 1]

        return NewCFrame(x, y, z, qx, qy, qz, qw), Cur + 21
    end

    QCFrameF24[SER] = QCFrameF24Ser
    QCFrameF24[DES] = QCFrameF24Des
end

const QCFrameF16: SerdesNode<CFrame> = {}
do
    const function QCFrameF16Ser(Value: CFrame, Buf: buffer, Cur: number): number
        const
        x, y, z,
        R00, R01, R02,
        R10, R11, R12,
        R20, R21, R22
        = Value:GetComponents()

        local qx: number, qy: number, qz: number, qw: number
        const Trace = R00 + R11 + R22
        if Trace > 0 then
            const S = math.sqrt(Trace + 1) * 2
            qx, qy, qz, qw = (R21 - R12) / S, (R02 - R20) / S, (R10 - R01) / S, S * 0.25
        elseif R00 > R11 and R00 > R22 then
            const S = math.sqrt(1 + R00 - R11 - R22) * 2
            qx, qy, qz, qw = S * 0.25, (R01 + R10) / S, (R02 + R20) / S, (R21 - R12) / S
        elseif R11 > R22 then
            const S = math.sqrt(1 + R11 - R00 - R22) * 2
            qx, qy, qz, qw = (R01 + R10) / S, S * 0.25, (R12 + R21) / S, (R02 - R20) / S
        else
            const S = math.sqrt(1 + R22 - R00 - R11) * 2
            qx, qy, qz, qw = (R02 + R20) / S, (R12 + R21) / S, S * 0.25, (R10 - R01) / S
        end

        const FloatConverter = FloatConverter

        do
            buffer.writef32(FloatConverter, 0, x)
            const Bits = buffer.readu32(FloatConverter, 0)
            const Sign = bit32.band(bit32.rshift(Bits, 16), 0x8000)
            const Abs = bit32.band(Bits, 0x7FFFFFFF) + 0x1000
            buffer.writeu16(Buf, Cur, if Abs >= 0x47800000 then Sign + 0x7BFF elseif Abs < 0x38800000 then Sign else Sign + bit32.rshift(Abs, 13) - 0x1C000)
        end
        do
            buffer.writef32(FloatConverter, 0, y)
            const Bits = buffer.readu32(FloatConverter, 0)
            const Sign = bit32.band(bit32.rshift(Bits, 16), 0x8000)
            const Abs = bit32.band(Bits, 0x7FFFFFFF) + 0x1000
            buffer.writeu16(Buf, Cur + 2, if Abs >= 0x47800000 then Sign + 0x7BFF elseif Abs < 0x38800000 then Sign else Sign + bit32.rshift(Abs, 13) - 0x1C000)
        end
        do
            buffer.writef32(FloatConverter, 0, z)
            const Bits = buffer.readu32(FloatConverter, 0)
            const Sign = bit32.band(bit32.rshift(Bits, 16), 0x8000)
            const Abs = bit32.band(Bits, 0x7FFFFFFF) + 0x1000
            buffer.writeu16(Buf, Cur + 4, if Abs >= 0x47800000 then Sign + 0x7BFF elseif Abs < 0x38800000 then Sign else Sign + bit32.rshift(Abs, 13) - 0x1C000)
        end
        do
            buffer.writef32(FloatConverter, 0, qx)
            const Bits = buffer.readu32(FloatConverter, 0)
            const Sign = bit32.band(bit32.rshift(Bits, 16), 0x8000)
            const Abs = bit32.band(Bits, 0x7FFFFFFF) + 0x1000
            buffer.writeu16(Buf, Cur + 6, if Abs >= 0x47800000 then Sign + 0x7BFF elseif Abs < 0x38800000 then Sign else Sign + bit32.rshift(Abs, 13) - 0x1C000)
        end
        do
            buffer.writef32(FloatConverter, 0, qy)
            const Bits = buffer.readu32(FloatConverter, 0)
            const Sign = bit32.band(bit32.rshift(Bits, 16), 0x8000)
            const Abs = bit32.band(Bits, 0x7FFFFFFF) + 0x1000
            buffer.writeu16(Buf, Cur + 8, if Abs >= 0x47800000 then Sign + 0x7BFF elseif Abs < 0x38800000 then Sign else Sign + bit32.rshift(Abs, 13) - 0x1C000)
        end
        do
            buffer.writef32(FloatConverter, 0, qz)
            const Bits = buffer.readu32(FloatConverter, 0)
            const Sign = bit32.band(bit32.rshift(Bits, 16), 0x8000)
            const Abs = bit32.band(Bits, 0x7FFFFFFF) + 0x1000
            buffer.writeu16(Buf, Cur + 10, if Abs >= 0x47800000 then Sign + 0x7BFF elseif Abs < 0x38800000 then Sign else Sign + bit32.rshift(Abs, 13) - 0x1C000)
        end
        do
            buffer.writef32(FloatConverter, 0, qw)
            const Bits = buffer.readu32(FloatConverter, 0)
            const Sign = bit32.band(bit32.rshift(Bits, 16), 0x8000)
            const Abs = bit32.band(Bits, 0x7FFFFFFF) + 0x1000
            buffer.writeu16(Buf, Cur + 12, if Abs >= 0x47800000 then Sign + 0x7BFF elseif Abs < 0x38800000 then Sign else Sign + bit32.rshift(Abs, 13) - 0x1C000)
        end

        return Cur + 14
    end

    const function QCFrameF16Des(Buf: buffer, Cur: number): (CFrame, number)
        const Scale = F16Scale
        const Px = buffer.readu16(Buf, Cur)
        const x = bit32.bor(bit32.band(Px, 0x3FF), 0x400) * Scale[bit32.rshift(Px, 10) + 1]
        const Py = buffer.readu16(Buf, Cur + 2)
        const y = bit32.bor(bit32.band(Py, 0x3FF), 0x400) * Scale[bit32.rshift(Py, 10) + 1]
        const Pz = buffer.readu16(Buf, Cur + 4)
        const z = bit32.bor(bit32.band(Pz, 0x3FF), 0x400) * Scale[bit32.rshift(Pz, 10) + 1]
        const Pqx = buffer.readu16(Buf, Cur + 6)
        const qx = bit32.bor(bit32.band(Pqx, 0x3FF), 0x400) * Scale[bit32.rshift(Pqx, 10) + 1]
        const Pqy = buffer.readu16(Buf, Cur + 8)
        const qy = bit32.bor(bit32.band(Pqy, 0x3FF), 0x400) * Scale[bit32.rshift(Pqy, 10) + 1]
        const Pqz = buffer.readu16(Buf, Cur + 10)
        const qz = bit32.bor(bit32.band(Pqz, 0x3FF), 0x400) * Scale[bit32.rshift(Pqz, 10) + 1]
        const Pqw = buffer.readu16(Buf, Cur + 12)
        const qw = bit32.bor(bit32.band(Pqw, 0x3FF), 0x400) * Scale[bit32.rshift(Pqw, 10) + 1]

        return NewCFrame(x, y, z, qx, qy, qz, qw), Cur + 14
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
        return Cur + 2
    end

    const function EnumDes(Buf: buffer, Cur: number): (GetEnumItem<T>, number)
        const Value = buffer.readu16(Buf, Cur)
        return EnumType:FromValue(Value), Cur + 2
    end

    Node[SER] = EnumSer
    Node[DES] = EnumDes
    return Node
end

const function Enum8<T>(EnumType: T & Enum): SerdesNode<GetEnumItem<T>>
    const Node: SerdesNode<GetEnumItem<T>> = {}
    
    const function Enum8Ser(Value: EnumItem & GetEnumItem<T>, Buf: buffer, Cur: number): number
        buffer.writeu8(Buf, Cur, Value.Value)
        return Cur + 1
    end

    const function Enum8Des(Buf: buffer, Cur: number): (GetEnumItem<T>, number)
        const Value = buffer.readu8(Buf, Cur)
        return EnumType:FromValue(Value), Cur + 1
    end

    Node[SER] = Enum8Ser
    Node[DES] = Enum8Des
    return Node
end

const function UDim2Quant(MinScale: number, MaxScale: number)
    const UDim2QuantNode: SerdesNode<UDim2> = {}
    const QuantizedScaleRange = MaxScale - MinScale
    const QuantizedScale = QuantizedScaleRange / 65535
    const InvQuantizedScale = 65535 / QuantizedScaleRange

    const function UDim2QuantSer(Value: UDim2, Buf: buffer, Cur: number): number
        const X, Y = Value.X, Value.Y
        const MinScale = MinScale
        const InvQuantizedScale = InvQuantizedScale
        buffer.writeu16(Buf, Cur, math.round((X.Scale - MinScale) * InvQuantizedScale))
        buffer.writeu16(Buf, Cur + 2, math.round((Y.Scale - MinScale) * InvQuantizedScale))
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

---------------------------------------------------------
-- TYPES
---------------------------------------------------------

Types.U8 = U8
Types.I8 = I8
Types.U16 = U16
Types.I16 = I16
Types.F16 = F16
Types.F24 = F24
Types.U24 = U24
Types.I24 = I24
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
Types.MapFixed = MapFixed
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
Types.Color3Round = Color3Round
Types.Enum = EnumNode
Types.Enum8 = Enum8
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

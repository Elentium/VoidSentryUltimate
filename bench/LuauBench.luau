--!native
const BenchTypes = require("./Types")
const Benchmark = require("./BenchHelper")

const WAIT_OR_TASK_WAIT = (task and task.wait) or wait

const VoidSentryUltimate = require("../LuauVS")
const VSTypes = VoidSentryUltimate.Types

const DefaultIterations = 10_000
const Results: BenchTypes.Results = {}
local CurrentSection: BenchTypes.Section? = nil

const Separator = ("_"):rep(50)
const SmallSeparator = "________________________"
const MedSeparator = "______________________________________"

const function Test(TestName: string, Func: () -> (), Iterations: number)
    if not CurrentSection then
        return
    end

    const Result = Benchmark(Func, Iterations)

    table.insert(CurrentSection.Nodes, {
        Name = TestName,
        Result = Result,
    })
end

const function Section(Name: string)
    CurrentSection = {
        SectionName = Name,
        Nodes = {},
    }
    table.insert(Results, CurrentSection)
end

const function PrintResults(Iterations: number)
    print(Separator)
    print("* LUAU BENCH RESULTS")
    print(`* ITERATIONS: {Iterations}`)
    for _, SectionData in Results do
        print(`** {SectionData.SectionName}:`)
        for _, Entry in SectionData.Nodes do
            print(SmallSeparator)
            print(`*** {Entry.Name}:`)
            print(`**** Total: {string.format("%.2f", Entry.Result.Total)}ms`)
            print(`**** Avg: {string.format("%.2f", Entry.Result.Avg)}μs`)
            print(`**** Min: {string.format("%.2f", Entry.Result.Min)}μs`)
            print(`**** Max: {string.format("%.2f", Entry.Result.Max)}μs`)
            print(`**** Med: {string.format("%.2f", Entry.Result.Med)}μs`)
            print(SmallSeparator)
        end
        print(MedSeparator)
    end
    print(Separator)
end

const function YieldIfPossible()
    if WAIT_OR_TASK_WAIT then
        WAIT_OR_TASK_WAIT()
    end
end

const function LuauBench(Log: boolean?, Iterations: number?)
    table.clear(Results)
    const Iter = Iterations or DefaultIterations

    const Serialize = VoidSentryUltimate.Serialize
    const Deserialize = VoidSentryUltimate.Deserialize

    const function BenchPrimitive(Name: string, Schema: VoidSentryUltimate.SerdesNode<any>, Value: any)
        Test(`{Name} Serialize`, function()
            Serialize(Schema, Value)
        end, Iter)

        const Buf = Serialize(Schema, Value)
        Test(`{Name} Deserialize`, function()
            Deserialize(Schema, Buf)
        end, Iter)

        Test(`{Name} RoundTrip`, function()
            Deserialize(Schema, Serialize(Schema, Value))
        end, Iter)
    end

    const function BenchVector(Name: string, Schema: VoidSentryUltimate.SerdesNode<vector>, Value: vector)
        Test(`{Name} Serialize`, function()
            Serialize(Schema, Value)
        end, Iter)

        const Buf = Serialize(Schema, Value)
        Test(`{Name} Deserialize`, function()
            Deserialize(Schema, Buf)
        end, Iter)

        Test(`{Name} RoundTrip`, function()
            Deserialize(Schema, Serialize(Schema, Value))
        end, Iter)
    end

    const function BenchBuffer(Name: string, Schema: VoidSentryUltimate.SerdesNode<buffer>, Value: buffer, Bytes: number)
        Test(`{Name} ({Bytes}b) Serialize`, function()
            Serialize(Schema, Value)
        end, Iter)

        const Buf = Serialize(Schema, Value)
        Test(`{Name} ({Bytes}b) Deserialize`, function()
            Deserialize(Schema, Buf)
        end, Iter)

        Test(`{Name} ({Bytes}b) RoundTrip`, function()
            Deserialize(Schema, Serialize(Schema, Value))
        end, Iter)
    end

    const function MakeU8Array(Count: number): { number }
        local Arr: { number } = {}
        for i = 1, Count do
            Arr[i] = i % 256
        end
        return Arr
    end

    const function MakeU8Map(Count: number): { [number]: number }
        local Map: { [number]: number } = {}
        for i = 1, Count do
            Map[i] = i % 256
        end
        return Map
    end

    const function MakeU8StructSchema(Count: number): any
        local Tbl: { [string]: any } = {}
        for i = 1, Count do
            Tbl[`f{string.format("%03d", i)}`] = VSTypes.U8
        end
        return VSTypes.Struct(Tbl)
    end

    const function MakeU8DeltaStructSchema(Count: number): any
        local Tbl: { [string]: any } = {}
        for i = 1, Count do
            Tbl[`f{string.format("%03d", i)}`] = VSTypes.U8
        end
        return VSTypes.DeltaStruct(Tbl)
    end

    const function MakeU8DeltaStruct16Schema(Count: number): any
        local Tbl: { [string]: any } = {}
        for i = 1, Count do
            Tbl[`f{string.format("%03d", i)}`] = VSTypes.U8
        end
        return VSTypes.DeltaStruct16(Tbl)
    end

    const function MakeU8StructValue(Count: number): { [string]: number }
        local Tbl: { [string]: number } = {}
        for i = 1, Count do
            Tbl[`f{string.format("%03d", i)}`] = i % 256
        end
        return Tbl
    end

    const function MakeU8DeltaValue(Count: number, Present: number): { [string]: number }
        local Tbl: { [string]: number } = {}
        for i = 1, Present do
            Tbl[`f{string.format("%03d", i)}`] = i % 256
        end
        return Tbl
    end

    const U8Array = VSTypes.Array(VSTypes.U8)
    const U8Array24 = VSTypes.Array24(VSTypes.U8)
    const U8Map = VSTypes.Map(VSTypes.U8, VSTypes.U8)
    const U8Map24 = VSTypes.Map24(VSTypes.U8, VSTypes.U8)

    const TestVector = vector.create(1, 2, 3)
    const PayloadSize = 32
    const Payload = buffer.create(PayloadSize)

    Section("Number Types")
    BenchPrimitive("U8", VSTypes.U8, 42)
    BenchPrimitive("I8", VSTypes.I8, -42)
    BenchPrimitive("U16", VSTypes.U16, 42)
    YieldIfPossible()
    BenchPrimitive("I16", VSTypes.I16, -42)
    BenchPrimitive("U24", VSTypes.U24, 42)
    BenchPrimitive("I24", VSTypes.I24, -42)
    YieldIfPossible()
    BenchPrimitive("U32", VSTypes.U32, 42)
    BenchPrimitive("I32", VSTypes.I32, -42)
    BenchPrimitive("F16", VSTypes.F16, 3.14)
    YieldIfPossible()
    BenchPrimitive("F24", VSTypes.F24, 3.14)
    BenchPrimitive("F32", VSTypes.F32, 3.14)
    BenchPrimitive("F64", VSTypes.F64, 3.14)
    YieldIfPossible()

    Section("Vector Types")
    BenchVector("Vector", VSTypes.Vector, TestVector)
    BenchVector("VectorF16", VSTypes.VectorF16, TestVector)
    BenchVector("VectorF24", VSTypes.VectorF24, TestVector)
    YieldIfPossible()
    BenchVector("VectorU8", VSTypes.VectorU8, TestVector)
    BenchVector("VectorI8", VSTypes.VectorI8, TestVector)
    BenchVector("VectorU16", VSTypes.VectorU16, TestVector)
    YieldIfPossible()
    BenchVector("VectorI16", VSTypes.VectorI16, TestVector)
    BenchVector("VectorU24", VSTypes.VectorU24, TestVector)
    BenchVector("VectorI24", VSTypes.VectorI24, TestVector)
    YieldIfPossible()

    Section("Buffer Types")
    BenchBuffer("Buffer", VSTypes.Buffer, Payload, 2 + PayloadSize)
    BenchBuffer("Buffer8", VSTypes.Buffer8, Payload, 1 + PayloadSize)
    BenchBuffer("Buffer24", VSTypes.Buffer24, Payload, 3 + PayloadSize)
    YieldIfPossible()
    BenchBuffer("BufferFixed", VSTypes.BufferFixed(PayloadSize), Payload, PayloadSize)

    Section("Other Primitives")
    BenchPrimitive("Bool", VSTypes.Bool, true)
    BenchPrimitive("BoolPacked", VSTypes.BoolPacked, { true, false, true, false, true, false, true, false })
    YieldIfPossible()
    BenchPrimitive("String (1 char)", VSTypes.String, "a")
    BenchPrimitive("String (10 chars)", VSTypes.String, "aaaaaaaaaa")
    BenchPrimitive("String (100 chars)", VSTypes.String, ("a"):rep(100))
    YieldIfPossible()

    Section("Collection Types")
    BenchPrimitive("Array (1 elem)", U8Array, MakeU8Array(1))
    BenchPrimitive("Map (1 elem)", U8Map, MakeU8Map(1))
    BenchPrimitive("Struct (1 elem)", MakeU8StructSchema(1), MakeU8StructValue(1))
    BenchPrimitive("DeltaStruct (1/10 present)", MakeU8DeltaStructSchema(10), MakeU8DeltaValue(10, 1))
    YieldIfPossible()
    BenchPrimitive("Array (10 elem)", U8Array, MakeU8Array(10))
    BenchPrimitive("Array24 (10 elem)", U8Array24, MakeU8Array(10))
    BenchPrimitive("Map (10 elem)", U8Map, MakeU8Map(10))
    YieldIfPossible()
    BenchPrimitive("Map24 (10 elem)", U8Map24, MakeU8Map(10))
    BenchPrimitive("Struct (10 elem)", MakeU8StructSchema(10), MakeU8StructValue(10))
    BenchPrimitive("DeltaStruct (3/10 present)", MakeU8DeltaStructSchema(10), MakeU8DeltaValue(10, 3))
    YieldIfPossible()
    BenchPrimitive("DeltaStruct16 (3/10 present)", MakeU8DeltaStruct16Schema(10), MakeU8DeltaValue(10, 3))
    BenchPrimitive("Array (100 elem)", U8Array, MakeU8Array(100))
    YieldIfPossible()
    BenchPrimitive("Map (100 elem)", U8Map, MakeU8Map(100))
    BenchPrimitive("Struct (100 elem)", MakeU8StructSchema(100), MakeU8StructValue(100))
    BenchPrimitive("DeltaStruct (10/100 present)", MakeU8DeltaStructSchema(100), MakeU8DeltaValue(100, 10))
    YieldIfPossible()

    if Log then
        PrintResults(Iter)
    end

    return table.clone(Results)
end

return LuauBench

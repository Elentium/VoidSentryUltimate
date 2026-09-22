--!native
const TestTypes = require("./Types")
const TestHelper = require("./TestHelper")

const VoidSentryUltimate = require("../LuauVS")
const VSTypes = VoidSentryUltimate.Types

const Results: TestTypes.Results = {}
local CurrentSection: TestTypes.Section? = nil

const Separator = ("_"):rep(50)
const SmallSeparator = "________________________"
const MedSeparator = "______________________________________"

const function Section(Name: string)
    CurrentSection = {
        SectionName = Name,
        Nodes = {},
    }
    table.insert(Results, CurrentSection)
end

const function AddTest(Result: TestTypes.TestResult)
    if not CurrentSection then
        return
    end
    table.insert(CurrentSection.Nodes, Result)
end

const function RunTest(
    Name: string,
    Schema: any,
    Value: any,
    ExpectedSize: number,
    Compare: (any, any) -> boolean
)
    AddTest(TestHelper.RunTest(Name, {
        Serialize = VoidSentryUltimate.Serialize,
        Deserialize = VoidSentryUltimate.Deserialize,
        Schema = Schema,
        Value = Value,
        ExpectedSize = ExpectedSize,
        Compare = Compare,
    }))
end

const function PrintResults()
    print(Separator)
    print("* LUAU TEST RESULTS")
    for _, SectionData in Results do
        print(`** {SectionData.SectionName}:`)
        for _, Result in SectionData.Nodes do
            print(SmallSeparator)
            print(`*** {Result.Name}: {if Result.Valid then "PASS" else "FAIL"}`)
        end
        print(MedSeparator)
    end
    const Passed, Total = TestHelper.CountResults(Results)
    const Percent = if Total == 0 then 0 else (Passed / Total) * 100
    print(`* SUCCESS: {Passed}/{Total} ({string.format("%.1f", Percent)}%)`)
    print(Separator)
end

const function LuauTest(Log: boolean?)
    table.clear(Results)

    const TestVector = vector.create(1, 2, 3)
    const PayloadSize = 16
    const Payload = buffer.create(PayloadSize)
    buffer.fill(Payload, 0, 0xAB)

    const U8Array = VSTypes.Array(VSTypes.U8)
    const U8Array8 = VSTypes.Array8(VSTypes.U8)
    const U8Array24 = VSTypes.Array24(VSTypes.U8)
    const U8ArrayFixed = VSTypes.ArrayFixed(VSTypes.U8, 3)
    const U8Map = VSTypes.Map(VSTypes.U8, VSTypes.U8)
    const U8Map8 = VSTypes.Map8(VSTypes.U8, VSTypes.U8)
    const U8Map24 = VSTypes.Map24(VSTypes.U8, VSTypes.U8)
    const U8MapFixed = VSTypes.MapFixed(VSTypes.U8, VSTypes.U8, 2)
    const U8Optional = VSTypes.Optional(VSTypes.U8)

    const TestStructSchema = VSTypes.Struct({
        a = VSTypes.U8,
        b = VSTypes.U16,
        c = VSTypes.Bool,
    })
    const TestStructValue = {
        a = 1,
        b = 2,
        c = true,
    }

    const TestDeltaSchema = VSTypes.DeltaStruct({
        a = VSTypes.U8,
        b = VSTypes.U16,
        c = VSTypes.Bool,
    })
    const TestDeltaValue = {
        a = 1,
        b = 2,
    }
    const TestDelta16Schema = VSTypes.DeltaStruct16({
        a = VSTypes.U8,
        b = VSTypes.U16,
        c = VSTypes.Bool,
    })

    const function CompareStructLike(A: any, B: any): boolean
        return TestHelper.StructsEq(A, B, function(AValue, BValue)
            if type(AValue) == "number" then
                return TestHelper.NumbersEq(AValue, BValue)
            end
            return TestHelper.BoolsEq(AValue, BValue)
        end)
    end

    Section("Number Types")
    RunTest("U8", VSTypes.U8, 42, 1, TestHelper.NumbersEq)
    RunTest("I8", VSTypes.I8, -42, 1, TestHelper.NumbersEq)
    RunTest("U16", VSTypes.U16, 1000, 2, TestHelper.NumbersEq)
    RunTest("I16", VSTypes.I16, -1000, 2, TestHelper.NumbersEq)
    RunTest("U24", VSTypes.U24, 42, 3, TestHelper.NumbersEq)
    RunTest("I24", VSTypes.I24, -42, 3, TestHelper.NumbersEq)
    RunTest("U32", VSTypes.U32, 100_000, 4, TestHelper.NumbersEq)
    RunTest("I32", VSTypes.I32, -100_000, 4, TestHelper.NumbersEq)
    RunTest("U40", VSTypes.U40, 100_000_000_000, 5, TestHelper.NumbersEq)
    RunTest("I40", VSTypes.I40, -100_000_000_000, 5, TestHelper.NumbersEq)
    RunTest("U48", VSTypes.U48, 1_000_000_000_000, 6, TestHelper.NumbersEq)
    RunTest("I48", VSTypes.I48, -1_000_000_000_000, 6, TestHelper.NumbersEq)
    RunTest("F16", VSTypes.F16, 3.14, 2, TestHelper.NumbersApproxF16)
    RunTest("F24", VSTypes.F24, 3.14, 3, TestHelper.NumbersApprox)
    RunTest("F32", VSTypes.F32, 3.14, 4, TestHelper.NumbersApprox)
    RunTest("F64", VSTypes.F64, 3.14, 8, TestHelper.NumbersApprox)

    Section("Vector Types")
    RunTest("Vector", VSTypes.Vector, TestVector, 12, TestHelper.VectorsEq)
    RunTest("VectorF16", VSTypes.VectorF16, TestVector, 6, TestHelper.VectorsApprox)
    RunTest("VectorF24", VSTypes.VectorF24, TestVector, 9, TestHelper.VectorsApprox)
    RunTest("VectorU8", VSTypes.VectorU8, TestVector, 3, TestHelper.VectorsApprox)
    RunTest("VectorI8", VSTypes.VectorI8, TestVector, 3, TestHelper.VectorsApprox)
    RunTest("VectorU16", VSTypes.VectorU16, TestVector, 6, TestHelper.VectorsApprox)
    RunTest("VectorI16", VSTypes.VectorI16, TestVector, 6, TestHelper.VectorsApprox)
    RunTest("VectorU24", VSTypes.VectorU24, TestVector, 9, TestHelper.VectorsApprox)
    RunTest("VectorI24", VSTypes.VectorI24, TestVector, 9, TestHelper.VectorsApprox)

    Section("Buffer Types")
    RunTest("Buffer", VSTypes.Buffer, Payload, 2 + PayloadSize, TestHelper.BuffersEq)
    RunTest("Buffer8", VSTypes.Buffer8, Payload, 1 + PayloadSize, TestHelper.BuffersEq)
    RunTest("Buffer24", VSTypes.Buffer24, Payload, 3 + PayloadSize, TestHelper.BuffersEq)
    RunTest("BufferFixed", VSTypes.BufferFixed(PayloadSize), Payload, PayloadSize, TestHelper.BuffersEq)

    Section("Other Primitives")
    RunTest("Bool", VSTypes.Bool, true, 1, TestHelper.BoolsEq)
    RunTest("BoolPacked", VSTypes.BoolPacked, { true, false, true, false, true, false, true, false }, 1, function(A, B)
        return TestHelper.ArraysEq(A, B, TestHelper.BoolsEq)
    end)
    RunTest("String", VSTypes.String, "hello", 2 + 5, TestHelper.StringsEq)
    RunTest("String8", VSTypes.String8, "hello", 1 + 5, TestHelper.StringsEq)
    RunTest("StringFixed", VSTypes.StringFixed(8), "12345678", 8, TestHelper.StringsEq)
    RunTest("Optional", U8Optional, 42, 2, TestHelper.NumbersEq)

    Section("Collection Types")
    RunTest("Array", U8Array, { 1, 2, 3 }, 2 + 3, function(A, B)
        return TestHelper.ArraysEq(A, B, TestHelper.NumbersEq)
    end)
    RunTest("Array8", U8Array8, { 1, 2, 3 }, 1 + 3, function(A, B)
        return TestHelper.ArraysEq(A, B, TestHelper.NumbersEq)
    end)
    RunTest("Array24", U8Array24, { 1, 2, 3 }, 3 + 3, function(A, B)
        return TestHelper.ArraysEq(A, B, TestHelper.NumbersEq)
    end)
    RunTest("ArrayFixed", U8ArrayFixed, { 1, 2, 3 }, 3, function(A, B)
        return TestHelper.ArraysEq(A, B, TestHelper.NumbersEq)
    end)
    RunTest("Map", U8Map, { [1] = 2, [3] = 4 }, 2 + 4, function(A, B)
        return TestHelper.MapsEq(A, B, TestHelper.NumbersEq)
    end)
    RunTest("Map8", U8Map8, { [1] = 2, [3] = 4 }, 1 + 4, function(A, B)
        return TestHelper.MapsEq(A, B, TestHelper.NumbersEq)
    end)
    RunTest("Map24", U8Map24, { [1] = 2, [3] = 4 }, 3 + 4, function(A, B)
        return TestHelper.MapsEq(A, B, TestHelper.NumbersEq)
    end)
    RunTest("MapFixed", U8MapFixed, { [1] = 2, [2] = 3 }, 4, function(A, B)
        return TestHelper.MapsEq(A, B, TestHelper.NumbersEq)
    end)
    RunTest("Struct", TestStructSchema, TestStructValue, 4, CompareStructLike)
    -- keys sorted a,b,c; present a,b => u8 len + (id+u8) + (id+u16) = 1+2+3 = 6
    RunTest("DeltaStruct", TestDeltaSchema, TestDeltaValue, 6, CompareStructLike)
    -- same payload with u16 len + u16 ids => 2+3+4 = 9
    RunTest("DeltaStruct16", TestDelta16Schema, TestDeltaValue, 9, CompareStructLike)

    if Log then
        PrintResults()
    end

    return table.clone(Results)
end

return LuauTest

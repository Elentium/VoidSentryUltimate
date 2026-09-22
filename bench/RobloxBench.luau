--!native
--!nonstrict
const Types = require("./Types")
const Benchmark = require("./BenchHelper")
const VoidSentryUltimate = require("../VoidSentryUltimate")
const VSTypes = VoidSentryUltimate.Types

const DefaultIterations = 10_000
const Results: Types.Results = {}
local CurrentSection: Types.Section? = nil

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
    print("* ROBLOX BENCH RESULTS")
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

const function RobloxBench(Log: boolean?, Iterations: number?)
    table.clear(Results)
    const Serialize = VoidSentryUltimate.Serialize
    const Deserialize = VoidSentryUltimate.Deserialize

    const Iter = Iterations or DefaultIterations

    const function Bench(Name: string, Schema: VoidSentryUltimate.SerdesNode<any>, Value: any)
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

    const TestCFrame = CFrame.new(1, 2, 3) * CFrame.Angles(0.5, 1, 0.25)
    const TestColor3 = Color3.fromRGB(255, 128, 64)

    Section("CFrame Types")
    Bench("CFrame", VSTypes.CFrame, TestCFrame)
    Bench("QCFrame", VSTypes.QCFrame, TestCFrame)
    Bench("CFrameF16", VSTypes.CFrameF16, TestCFrame)
    Bench("CFrameF24", VSTypes.CFrameF24, TestCFrame)
    Bench("QCFrameF16", VSTypes.QCFrameF16, TestCFrame)
    Bench("QCFrameF24", VSTypes.QCFrameF24, TestCFrame)
    Bench("CFrameQuantF16", VSTypes.CFrameQuantF16, TestCFrame)
    Bench("CFrameQuant8F16", VSTypes.CFrameQuant8F16, TestCFrame)

    task.wait()

    const BenchPart = Instance.new("Part")
    BenchPart.Size = Vector3.new(4, 2, 1)
    BenchPart.Color = TestColor3
    BenchPart.Parent = workspace
    task.wait()

    Section("Instance Types")
    Bench("Instance", VSTypes.Instance, BenchPart)
    Bench("Instance24", VSTypes.Instance24, BenchPart)

    const SerInstSchema = VSTypes.SerInstance("Part", {
        Size = VSTypes.Vector,
        Color = VSTypes.Color3,
    })
    Bench("SerInstance", SerInstSchema, BenchPart)

    task.wait()

    Section("Other Roblox Types")
    Bench("Color3", VSTypes.Color3, TestColor3)

    const TestVector2 = Vector2.new(1, 2)

    Section("Vector2 Types")
    Bench("Vector2", VSTypes.Vector2, TestVector2)
    Bench("Vector2F16", VSTypes.Vector2F16, TestVector2)
    Bench("Vector2F24", VSTypes.Vector2F24, TestVector2)
    Bench("Vector2U8", VSTypes.Vector2U8, TestVector2)
    Bench("Vector2I8", VSTypes.Vector2I8, TestVector2)
    Bench("Vector2U16", VSTypes.Vector2U16, TestVector2)
    Bench("Vector2I16", VSTypes.Vector2I16, TestVector2)
    Bench("Vector2U24", VSTypes.Vector2U24, TestVector2)
    Bench("Vector2I24", VSTypes.Vector2I24, TestVector2)

    const TestUDim2 = UDim2.new(0.5, 10, 0.25, 20)
    const TestUDim2Scale = UDim2.fromScale(0.5, 0.25)
    const TestUDim2Offset = UDim2.fromOffset(10, 20)
    const TestUDim2OffsetI16 = UDim2.fromOffset(100, 200)

    Section("UDim2 Types")
    Bench("UDim2", VSTypes.UDim2, TestUDim2)
    Bench("UDim2Scale", VSTypes.UDim2Scale, TestUDim2Scale)
    Bench("UDim2Offset", VSTypes.UDim2Offset, TestUDim2Offset)
    Bench("UDim2OffsetI16", VSTypes.UDim2OffsetI16, TestUDim2OffsetI16)
    Bench("UDim2ScaleF24", VSTypes.UDim2ScaleF24, TestUDim2Scale)
    Bench("UDim2Quant", VSTypes.UDim2Quant(0, 1), TestUDim2Scale)

    if Log then
        PrintResults(Iter)
    end

    return table.clone(Results)
end

return RobloxBench

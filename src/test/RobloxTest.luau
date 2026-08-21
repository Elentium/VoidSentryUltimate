--!native
const TestTypes = require("./Types")
const TestHelper = require("./TestHelper")

const VoidSentryUltimate = require("../VoidSentryUltimate")
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
    print("* ROBLOX TEST RESULTS")
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

const function RobloxTest(Log: boolean?)
    table.clear(Results)

    const TestCFrame = CFrame.new(1, 2, 3) * CFrame.Angles(0.5, 1, 0.25)
    const TestColor3 = Color3.fromRGB(255, 128, 64)

    Section("CFrame Types")
    RunTest("CFrame", VSTypes.CFrame, TestCFrame, 48, TestHelper.CFramesApprox)
    RunTest("QCFrame", VSTypes.QCFrame, TestCFrame, 28, TestHelper.CFramesApprox)
    RunTest("CFrameF16", VSTypes.CFrameF16, TestCFrame, 24, TestHelper.CFramesApproxF16)
    RunTest("CFrameF24", VSTypes.CFrameF24, TestCFrame, 36, TestHelper.CFramesApprox)
    RunTest("QCFrameF16", VSTypes.QCFrameF16, TestCFrame, 14, TestHelper.CFramesApproxF16)
    RunTest("QCFrameF24", VSTypes.QCFrameF24, TestCFrame, 21, TestHelper.CFramesApprox)

    const BenchPart = Instance.new("Part")
    BenchPart.Size = Vector3.new(4, 2, 1)
    BenchPart.Color = TestColor3
    BenchPart.Parent = workspace
    task.wait()

    Section("Instance Types")
    RunTest("Instance", VSTypes.Instance, BenchPart, 2, TestHelper.InstancesEq)
    RunTest("Instance24", VSTypes.Instance24, BenchPart, 3, TestHelper.InstancesEq)

    const SerInstSchema = VSTypes.SerInstance("Part", {
        Size = VSTypes.Vector,
        Color = VSTypes.Color3,
    })
    RunTest("SerInstance", SerInstSchema, BenchPart, 15, function(Original: Part, Decoded: Part)
        return TestHelper.Vector3sEq(Original.Size, Decoded.Size)
            and TestHelper.Color3sEq(Original.Color, Decoded.Color)
    end)

    Section("Other Roblox Types")
    RunTest("Color3", VSTypes.Color3, TestColor3, 3, TestHelper.Color3sEq)

    const TestVector2 = Vector2.new(1, 2)

    Section("Vector2 Types")
    RunTest("Vector2", VSTypes.Vector2, TestVector2, 8, TestHelper.Vector2sEq)
    RunTest("Vector2F16", VSTypes.Vector2F16, TestVector2, 4, TestHelper.Vector2sApproxF16)
    RunTest("Vector2F24", VSTypes.Vector2F24, TestVector2, 6, TestHelper.Vector2sApprox)
    RunTest("Vector2U8", VSTypes.Vector2U8, TestVector2, 2, TestHelper.Vector2sEq)
    RunTest("Vector2I8", VSTypes.Vector2I8, TestVector2, 2, TestHelper.Vector2sEq)
    RunTest("Vector2U16", VSTypes.Vector2U16, TestVector2, 4, TestHelper.Vector2sEq)
    RunTest("Vector2I16", VSTypes.Vector2I16, TestVector2, 4, TestHelper.Vector2sEq)
    RunTest("Vector2U24", VSTypes.Vector2U24, TestVector2, 6, TestHelper.Vector2sEq)
    RunTest("Vector2I24", VSTypes.Vector2I24, TestVector2, 6, TestHelper.Vector2sEq)

    const TestUDim2 = UDim2.new(0.5, 10, 0.25, 20)
    const TestUDim2Scale = UDim2.fromScale(0.5, 0.25)
    const TestUDim2Offset = UDim2.fromOffset(10, 20)
    const TestUDim2OffsetI16 = UDim2.fromOffset(100, 200)

    Section("UDim2 Types")
    RunTest("UDim2", VSTypes.UDim2, TestUDim2, 16, TestHelper.UDim2sEq)
    RunTest("UDim2Scale", VSTypes.UDim2Scale, TestUDim2Scale, 8, TestHelper.UDim2sEq)
    RunTest("UDim2Offset", VSTypes.UDim2Offset, TestUDim2Offset, 8, TestHelper.UDim2sEq)
    RunTest("UDim2OffsetI16", VSTypes.UDim2OffsetI16, TestUDim2OffsetI16, 4, TestHelper.UDim2sEq)
    RunTest("UDim2ScaleF24", VSTypes.UDim2ScaleF24, TestUDim2Scale, 6, TestHelper.UDim2sApproxScale)

    if Log then
        PrintResults()
    end

    return table.clone(Results)
end

return RobloxTest

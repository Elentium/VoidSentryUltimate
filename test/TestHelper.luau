--!native
const Types = require("./Types")

const DefaultEpsilon = 1e-3
const F16Epsilon = 1e-2

const function ApproxEq(A: number, B: number, Epsilon: number?): boolean
    return math.abs(A - B) <= (Epsilon or DefaultEpsilon)
end

const function NumbersEq(A: number, B: number): boolean
    return A == B
end

const function NumbersApprox(A: number, B: number): boolean
    return ApproxEq(A, B)
end

const function NumbersApproxF16(A: number, B: number): boolean
    return ApproxEq(A, B, F16Epsilon)
end

const function BoolsEq(A: boolean, B: boolean): boolean
    return A == B
end

const function StringsEq(A: string, B: string): boolean
    return A == B
end

const function BuffersEq(A: buffer, B: buffer): boolean
    if buffer.len(A) ~= buffer.len(B) then
        return false
    end
    return buffer.tostring(A) == buffer.tostring(B)
end

const function VectorsEq(A: vector, B: vector): boolean
    return A.x == B.x and A.y == B.y and A.z == B.z
end

const function VectorsApprox(A: vector, B: vector): boolean
    return ApproxEq(A.x, B.x) and ApproxEq(A.y, B.y) and ApproxEq(A.z, B.z)
end

const function Vector3sEq(A: Vector3, B: Vector3): boolean
    return A.X == B.X and A.Y == B.Y and A.Z == B.Z
end

const function Vector3sApprox(A: Vector3, B: Vector3): boolean
    return ApproxEq(A.X, B.X) and ApproxEq(A.Y, B.Y) and ApproxEq(A.Z, B.Z)
end

const function Vector2sEq(A: Vector2, B: Vector2): boolean
    return A.X == B.X and A.Y == B.Y
end

const function Vector2sApprox(A: Vector2, B: Vector2): boolean
    return ApproxEq(A.X, B.X) and ApproxEq(A.Y, B.Y)
end

const function Vector2sApproxF16(A: Vector2, B: Vector2): boolean
    return ApproxEq(A.X, B.X, F16Epsilon) and ApproxEq(A.Y, B.Y, F16Epsilon)
end

const function UDim2sEq(A: UDim2, B: UDim2): boolean
    return A.X.Scale == B.X.Scale
        and A.X.Offset == B.X.Offset
        and A.Y.Scale == B.Y.Scale
        and A.Y.Offset == B.Y.Offset
end

const function UDim2sApproxScale(A: UDim2, B: UDim2): boolean
    return ApproxEq(A.X.Scale, B.X.Scale)
        and ApproxEq(A.Y.Scale, B.Y.Scale)
        and A.X.Offset == B.X.Offset
        and A.Y.Offset == B.Y.Offset
end

const function Color3sEq(A: Color3, B: Color3): boolean
    return A.R == B.R and A.G == B.G and A.B == B.B
end

const function CFramesApprox(A: CFrame, B: CFrame): boolean
    const Ax, Ay, Az, Ar0, Ar01, Ar02, Ar10, Ar11, Ar12, Ar20, Ar21, Ar22 = A:GetComponents()
    const Bx, By, Bz, Br0, Br01, Br02, Br10, Br11, Br12, Br20, Br21, Br22 = B:GetComponents()
    return ApproxEq(Ax, Bx)
        and ApproxEq(Ay, By)
        and ApproxEq(Az, Bz)
        and ApproxEq(Ar0, Br0)
        and ApproxEq(Ar01, Br01)
        and ApproxEq(Ar02, Br02)
        and ApproxEq(Ar10, Br10)
        and ApproxEq(Ar11, Br11)
        and ApproxEq(Ar12, Br12)
        and ApproxEq(Ar20, Br20)
        and ApproxEq(Ar21, Br21)
        and ApproxEq(Ar22, Br22)
end

const function CFramesApproxF16(A: CFrame, B: CFrame): boolean
    const Ax, Ay, Az, Ar0, Ar01, Ar02, Ar10, Ar11, Ar12, Ar20, Ar21, Ar22 = A:GetComponents()
    const Bx, By, Bz, Br0, Br01, Br02, Br10, Br11, Br12, Br20, Br21, Br22 = B:GetComponents()
    return ApproxEq(Ax, Bx, F16Epsilon)
        and ApproxEq(Ay, By, F16Epsilon)
        and ApproxEq(Az, Bz, F16Epsilon)
        and ApproxEq(Ar0, Br0, F16Epsilon)
        and ApproxEq(Ar01, Br01, F16Epsilon)
        and ApproxEq(Ar02, Br02, F16Epsilon)
        and ApproxEq(Ar10, Br10, F16Epsilon)
        and ApproxEq(Ar11, Br11, F16Epsilon)
        and ApproxEq(Ar12, Br12, F16Epsilon)
        and ApproxEq(Ar20, Br20, F16Epsilon)
        and ApproxEq(Ar21, Br21, F16Epsilon)
        and ApproxEq(Ar22, Br22, F16Epsilon)
end

const function ArraysEq(A: { any }, B: { any }, Compare: (any, any) -> boolean): boolean
    if #A ~= #B then
        return false
    end
    for i = 1, #A do
        if not Compare(A[i], B[i]) then
            return false
        end
    end
    return true
end

const function MapsEq(A: { [any]: any }, B: { [any]: any }, Compare: (any, any) -> boolean): boolean
    for Key, Value in A do
        if B[Key] == nil or not Compare(Value, B[Key]) then
            return false
        end
    end
    for Key in B do
        if A[Key] == nil then
            return false
        end
    end
    return true
end

const function StructsEq(A: { [string]: any }, B: { [string]: any }, Compare: (any, any) -> boolean): boolean
    for Key, Value in A do
        if not Compare(Value, B[Key]) then
            return false
        end
    end
    for Key in B do
        if A[Key] == nil then
            return false
        end
    end
    return true
end

const function InstancesEq(A: Instance, B: Instance): boolean
    return A == B
end

export type RunTestOptions = {
    Serialize: (Schema: any, Value: any) -> buffer,
    Deserialize: (Schema: any, Buf: buffer) -> any,
    Schema: any,
    Value: any,
    ExpectedSize: number,
    Compare: (any, any) -> boolean,
}

const function RunTest(Name: string, Options: RunTestOptions): Types.TestResult
    local Valid = false

    const Ok = pcall(function()
        const Buf = Options.Serialize(Options.Schema, Options.Value)
        if buffer.len(Buf) ~= Options.ExpectedSize then
            error(`expected buffer size {Options.ExpectedSize}, got {buffer.len(Buf)}`)
        end

        const Decoded = Options.Deserialize(Options.Schema, Buf)
        if not Options.Compare(Options.Value, Decoded) then
            error("decoded value does not match original")
        end

        Valid = true
    end)

    return {
        Name = Name,
        Valid = Ok and Valid,
    }
end

const function CountResults(Results: Types.Results): (number, number)
    local Passed = 0
    local Total = 0
    for _, SectionData in Results do
        for _, Result in SectionData.Nodes do
            Total += 1
            if Result.Valid then
                Passed += 1
            end
        end
    end
    return Passed, Total
end

return {
    ApproxEq = ApproxEq,
    NumbersEq = NumbersEq,
    NumbersApprox = NumbersApprox,
    NumbersApproxF16 = NumbersApproxF16,
    BoolsEq = BoolsEq,
    StringsEq = StringsEq,
    BuffersEq = BuffersEq,
    VectorsEq = VectorsEq,
    VectorsApprox = VectorsApprox,
    Vector3sEq = Vector3sEq,
    Vector3sApprox = Vector3sApprox,
    Vector2sEq = Vector2sEq,
    Vector2sApprox = Vector2sApprox,
    Vector2sApproxF16 = Vector2sApproxF16,
    UDim2sEq = UDim2sEq,
    UDim2sApproxScale = UDim2sApproxScale,
    Color3sEq = Color3sEq,
    CFramesApprox = CFramesApprox,
    CFramesApproxF16 = CFramesApproxF16,
    ArraysEq = ArraysEq,
    MapsEq = MapsEq,
    StructsEq = StructsEq,
    InstancesEq = InstancesEq,
    RunTest = RunTest,
    CountResults = CountResults,
}

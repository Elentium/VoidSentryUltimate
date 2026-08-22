const Types = require("./Types")

@native const function Benchmark(Func: () -> (), Iterations: number): Types.BenchmarkResult
    const OverheadStart = os.clock()
    for _ = 1, Iterations do end
    const Overhead = os.clock() - OverheadStart

    -- warm up
    for _ = 1, 50 do
        Func()
    end

    const Result: Types.BenchmarkResult = {
        Min = 0,
        Max = 0,
        Avg = 0,
        Med = 0,
        Total = 0
    }
    local Sum = 0
    const Entries = table.create<<number>>(10)
    for i = 1, 10 do
        const Start = os.clock()
        for _ = 1, Iterations do
            Func()
        end
        const End = os.clock() - Start - Overhead
        const PerOp = (End * 1_000_000) / Iterations
        Sum += PerOp
        Entries[i] = PerOp
        Result.Total += End * 1_000
    end
    table.sort(Entries, function(a0: number, a1: number): boolean  
        return a0 < a1
    end)

    Result.Min = Entries[1]
    Result.Max = Entries[10]
    Result.Med = (Entries[5] + Entries[6]) / 2
    Result.Avg = Sum / 10

    return Result
end

return Benchmark
--!native
--!nonstrict
const BenchTypes = require("../Types")
const Benchmark = require("../BenchHelper")

const Sera = require("./Sera")
const VoidSentryUltimate = require("../../VoidSentryUltimate")
const VSTypes = VoidSentryUltimate.Types

const DefaultIterations = 10_000
const Results: BenchTypes.Results = {}
local CurrentSection: BenchTypes.Section? = nil

const Separator = ("_"):rep(50)
const SmallSeparator = "________________________"
const MedSeparator = "______________________________________"

const SchemaFieldCounts = { 1, 10, 100 }
const DeltaFieldCounts = { 3, 5, 10, 50, 100, 255 }
const PushFieldCounts = { 3, 5, 10, 50, 100, 255 }
const PushBufferSize = 256_000

type AvgPair = {
	SeraSum: number,
	VSSum: number,
	Count: number,
}

type CategoryTotals = {
	Serialize: AvgPair,
	Deserialize: AvgPair,
	Total: AvgPair,
}

const function NewAvgPair(): AvgPair
	return {
		SeraSum = 0,
		VSSum = 0,
		Count = 0,
	}
end

const function NewCategoryTotals(): CategoryTotals
	return {
		Serialize = NewAvgPair(),
		Deserialize = NewAvgPair(),
		Total = NewAvgPair(),
	}
end

const function RecordAvg(Pair: AvgPair, SeraValue: number, VSValue: number)
	Pair.SeraSum += SeraValue
	Pair.VSSum += VSValue
	Pair.Count += 1
end

const function RecordSerDesTotal(
	Cat: CategoryTotals,
	SeraSer: BenchTypes.BenchmarkResult,
	SeraDes: BenchTypes.BenchmarkResult,
	SeraRound: BenchTypes.BenchmarkResult,
	VSSer: BenchTypes.BenchmarkResult,
	VSDes: BenchTypes.BenchmarkResult,
	VSRound: BenchTypes.BenchmarkResult
)
	RecordAvg(Cat.Serialize, SeraSer.Avg, VSSer.Avg)
	RecordAvg(Cat.Deserialize, SeraDes.Avg, VSDes.Avg)
	RecordAvg(Cat.Total, SeraRound.Avg, VSRound.Avg)
end

const function WinnerLine(Label: string, Pair: AvgPair): string
	if Pair.Count == 0 then
		return `** {Label}: no samples`
	end
	const SeraAvg = Pair.SeraSum / Pair.Count
	const VSAvg = Pair.VSSum / Pair.Count
	const Winner = if VSAvg < SeraAvg then "VoidSentry" elseif SeraAvg < VSAvg then "Sera" else "Tie"
	local Ratio: string
	if Winner == "VoidSentry" then
		Ratio = string.format("%.2fx", SeraAvg / VSAvg)
	elseif Winner == "Sera" then
		Ratio = string.format("%.2fx", VSAvg / SeraAvg)
	else
		Ratio = "1.00x"
	end
	return `** {Label}: Sera {string.format("%.3f", SeraAvg)}μs | VS {string.format("%.3f", VSAvg)}μs → {Winner} faster ({Ratio})`
end

const function Test(TestName: string, Func: () -> (), Iterations: number): BenchTypes.BenchmarkResult
	const Result = Benchmark(Func, Iterations)

	if CurrentSection then
		table.insert(CurrentSection.Nodes, {
			Name = TestName,
			Result = Result,
		})
	end

	return Result
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
	print("* SERA VS VOIDSENTRY BENCH RESULTS")
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

const function PrintOverall(Title: string, Cat: CategoryTotals)
	print(Separator)
	print(`* {Title}`)
	print(WinnerLine("Serialize", Cat.Serialize))
	print(WinnerLine("Deserialize", Cat.Deserialize))
	print(WinnerLine("Total", Cat.Total))
	print(Separator)
end

const function PrintPushOverall(Title: string, Pair: AvgPair)
	print(Separator)
	print(`* {Title}`)
	if Pair.Count == 0 then
		print("** Push: no samples")
	else
		const SeraAvg = Pair.SeraSum / Pair.Count
		const VSAvg = Pair.VSSum / Pair.Count
		print("** Push:")
		print(`**** VoidSentry: {string.format("%.3f", VSAvg)}μs`)
		print(`**** Sera: {string.format("%.3f", SeraAvg)}μs`)
	end
	print(Separator)
end

const function MakeFieldName(Index: number): string
	return `f{string.format("%03d", Index)}`
end

const function MakeU8StructValue(Count: number): { [string]: number }
	local Tbl: { [string]: number } = {}
	for i = 1, Count do
		Tbl[MakeFieldName(i)] = i % 256
	end
	return Tbl
end

const function MakeDeltaValueAll(Count: number): { [string]: number }
	return MakeU8StructValue(Count)
end

const function MakeDeltaValueMissingOne(Count: number): { [string]: number }
	local Tbl = MakeU8StructValue(Count)
	Tbl[MakeFieldName(Count)] = nil :: any
	return Tbl
end

const function MakeDeltaValueOnlyOne(_Count: number): { [string]: number }
	return {
		[MakeFieldName(1)] = 1,
	}
end

const function MakeSeraU8Schema(Count: number): any
	local Params: { [string]: any } = {}
	for i = 1, Count do
		Params[MakeFieldName(i)] = Sera.Uint8
	end
	return Sera.Schema(Params)
end

const function MakeVSU8Schema(Count: number): any
	local Tbl: { [string]: any } = {}
	for i = 1, Count do
		Tbl[MakeFieldName(i)] = VSTypes.U8
	end
	return VoidSentryUltimate.Schema(Tbl)
end

const function Comparator(Log: boolean?, Iterations: number?): BenchTypes.Results
	table.clear(Results)
	const Iter = Iterations or DefaultIterations

	const VSSerialize = VoidSentryUltimate.Serialize
	const VSDeserialize = VoidSentryUltimate.Deserialize
	const SeraSerialize = Sera.Serialize
	const SeraDeserialize = Sera.Deserialize
	const SeraPush = Sera.Push
	const SeraDeltaSerialize = Sera.DeltaSerialize
	const SeraDeltaDeserialize = Sera.DeltaDeserialize
	const SeraDeltaPush = Sera.DeltaPush

	const PrimitiveTotals = NewCategoryTotals()
	const SchemaTotals = NewCategoryTotals()
	const DeltaTotals = NewCategoryTotals()
	const PushTotals = NewAvgPair()

	const TestVector = Vector3.new(1, 2, 3)
	const TestCFrame = CFrame.new(1, 2, 3) * CFrame.Angles(0.5, 1, 0.25)
	const F32Value = 3.14

	-- F32 (Sera wraps primitives in a single-field schema)
	do
		const SeraSchema = Sera.Schema({ v = Sera.Float32 })
		const SeraValue = { v = F32Value }
		const VSNode = VSTypes.F32

		Section("F32")
		const VSSer = Test("VS F32 Serialize", function()
			VSSerialize(VSNode, F32Value)
		end, Iter)
		const VSBuf = VSSerialize(VSNode, F32Value)
		const VSDes = Test("VS F32 Deserialize", function()
			VSDeserialize(VSNode, VSBuf)
		end, Iter)
		const VSRound = Test("VS F32 RoundTrip", function()
			VSDeserialize(VSNode, VSSerialize(VSNode, F32Value))
		end, Iter)

		const SeraSer = Test("Sera F32 Serialize", function()
			SeraSerialize(SeraSchema, SeraValue)
		end, Iter)
		const SeraBuf = SeraSerialize(SeraSchema, SeraValue)
		const SeraDes = Test("Sera F32 Deserialize", function()
			SeraDeserialize(SeraSchema, SeraBuf)
		end, Iter)
		const SeraRound = Test("Sera F32 RoundTrip", function()
			SeraDeserialize(SeraSchema, SeraSerialize(SeraSchema, SeraValue))
		end, Iter)

		RecordSerDesTotal(PrimitiveTotals, SeraSer, SeraDes, SeraRound, VSSer, VSDes, VSRound)
	end
	task.wait()

	-- Vector3
	do
		const SeraSchema = Sera.Schema({ v = Sera.Vector3 })
		const SeraValue = { v = TestVector }
		const VSNode = VSTypes.Vector

		Section("Vector3")
		const VSSer = Test("VS Vector3 Serialize", function()
			VSSerialize(VSNode, TestVector)
		end, Iter)
		const VSBuf = VSSerialize(VSNode, TestVector)
		const VSDes = Test("VS Vector3 Deserialize", function()
			VSDeserialize(VSNode, VSBuf)
		end, Iter)
		const VSRound = Test("VS Vector3 RoundTrip", function()
			VSDeserialize(VSNode, VSSerialize(VSNode, TestVector))
		end, Iter)

		const SeraSer = Test("Sera Vector3 Serialize", function()
			SeraSerialize(SeraSchema, SeraValue)
		end, Iter)
		const SeraBuf = SeraSerialize(SeraSchema, SeraValue)
		const SeraDes = Test("Sera Vector3 Deserialize", function()
			SeraDeserialize(SeraSchema, SeraBuf)
		end, Iter)
		const SeraRound = Test("Sera Vector3 RoundTrip", function()
			SeraDeserialize(SeraSchema, SeraSerialize(SeraSchema, SeraValue))
		end, Iter)

		RecordSerDesTotal(PrimitiveTotals, SeraSer, SeraDes, SeraRound, VSSer, VSDes, VSRound)
	end
	task.wait()

	-- CFrame (full matrix)
	do
		const SeraSchema = Sera.Schema({ v = Sera.CFrame })
		const SeraValue = { v = TestCFrame }
		const VSNode = VSTypes.CFrame

		Section("CFrame")
		const VSSer = Test("VS CFrame Serialize", function()
			VSSerialize(VSNode, TestCFrame)
		end, Iter)
		const VSBuf = VSSerialize(VSNode, TestCFrame)
		const VSDes = Test("VS CFrame Deserialize", function()
			VSDeserialize(VSNode, VSBuf)
		end, Iter)
		const VSRound = Test("VS CFrame RoundTrip", function()
			VSDeserialize(VSNode, VSSerialize(VSNode, TestCFrame))
		end, Iter)

		const SeraSer = Test("Sera CFrame Serialize", function()
			SeraSerialize(SeraSchema, SeraValue)
		end, Iter)
		const SeraBuf = SeraSerialize(SeraSchema, SeraValue)
		const SeraDes = Test("Sera CFrame Deserialize", function()
			SeraDeserialize(SeraSchema, SeraBuf)
		end, Iter)
		const SeraRound = Test("Sera CFrame RoundTrip", function()
			SeraDeserialize(SeraSchema, SeraSerialize(SeraSchema, SeraValue))
		end, Iter)

		RecordSerDesTotal(PrimitiveTotals, SeraSer, SeraDes, SeraRound, VSSer, VSDes, VSRound)
	end
	task.wait()

	-- LossyCFrame vs QCFrame (both 28-byte compressed rotations)
	do
		const SeraSchema = Sera.Schema({ v = Sera.LossyCFrame })
		const SeraValue = { v = TestCFrame }
		const VSNode = VSTypes.QCFrame

		Section("LossyCFrame / QCFrame")
		const VSSer = Test("VS QCFrame Serialize", function()
			VSSerialize(VSNode, TestCFrame)
		end, Iter)
		const VSBuf = VSSerialize(VSNode, TestCFrame)
		const VSDes = Test("VS QCFrame Deserialize", function()
			VSDeserialize(VSNode, VSBuf)
		end, Iter)
		const VSRound = Test("VS QCFrame RoundTrip", function()
			VSDeserialize(VSNode, VSSerialize(VSNode, TestCFrame))
		end, Iter)

		const SeraSer = Test("Sera LossyCFrame Serialize", function()
			SeraSerialize(SeraSchema, SeraValue)
		end, Iter)
		const SeraBuf = SeraSerialize(SeraSchema, SeraValue)
		const SeraDes = Test("Sera LossyCFrame Deserialize", function()
			SeraDeserialize(SeraSchema, SeraBuf)
		end, Iter)
		const SeraRound = Test("Sera LossyCFrame RoundTrip", function()
			SeraDeserialize(SeraSchema, SeraSerialize(SeraSchema, SeraValue))
		end, Iter)

		RecordSerDesTotal(PrimitiveTotals, SeraSer, SeraDes, SeraRound, VSSer, VSDes, VSRound)
	end
	task.wait()

	-- Schema (full struct serialize)
	for _, Count in SchemaFieldCounts do
		const SeraSchema = MakeSeraU8Schema(Count)
		const VSSchema = MakeVSU8Schema(Count)
		const VSSchemaSerialize = VSSchema.Serialize
		const VSSchemaDeserialize = VSSchema.Deserialize
		const Value = MakeU8StructValue(Count)
		const Label = `Schema ({Count} fields)`

		Section(Label)
		const VSSer = Test(`VS {Label} Serialize`, function()
			VSSchemaSerialize(Value)
		end, Iter)
		const VSBuf = VSSchemaSerialize(Value)
		const VSDes = Test(`VS {Label} Deserialize`, function()
			VSSchemaDeserialize(VSBuf)
		end, Iter)
		const VSRound = Test(`VS {Label} RoundTrip`, function()
			VSSchemaDeserialize(VSSchemaSerialize(Value))
		end, Iter)

		const SeraSer = Test(`Sera {Label} Serialize`, function()
			SeraSerialize(SeraSchema, Value)
		end, Iter)
		const SeraBuf = SeraSerialize(SeraSchema, Value)
		const SeraDes = Test(`Sera {Label} Deserialize`, function()
			SeraDeserialize(SeraSchema, SeraBuf)
		end, Iter)
		const SeraRound = Test(`Sera {Label} RoundTrip`, function()
			SeraDeserialize(SeraSchema, SeraSerialize(SeraSchema, Value))
		end, Iter)

		RecordSerDesTotal(SchemaTotals, SeraSer, SeraDes, SeraRound, VSSer, VSDes, VSRound)
		task.wait()
	end

	-- Delta schema
	for _, Count in DeltaFieldCounts do
		const SeraSchema = MakeSeraU8Schema(Count)
		const VSSchema = MakeVSU8Schema(Count)
		const VSDeltaSerialize = VSSchema.DeltaSerialize
		const VSDeltaDeserialize = VSSchema.DeltaDeserialize

		local Cases = {
			{ `Delta ({Count} fields, all present)`, MakeDeltaValueAll(Count) },
			{ `Delta ({Count} fields, 1 missing)`, MakeDeltaValueMissingOne(Count) },
			{ `Delta ({Count} fields, only 1 present)`, MakeDeltaValueOnlyOne(Count) },
		}

		for _, Case in Cases do
			const Label = Case[1]
			const Value = Case[2]

			Section(Label)
			const VSSer = Test(`VS {Label} Serialize`, function()
				VSDeltaSerialize(Value, 0)
			end, Iter)
			const VSBuf = VSDeltaSerialize(Value, 0)
			const VSDes = Test(`VS {Label} Deserialize`, function()
				VSDeltaDeserialize(VSBuf, 0)
			end, Iter)
			const VSRound = Test(`VS {Label} RoundTrip`, function()
				VSDeltaDeserialize(VSDeltaSerialize(Value, 0), 0)
			end, Iter)

			const SeraSer = Test(`Sera {Label} Serialize`, function()
				SeraDeltaSerialize(SeraSchema, Value)
			end, Iter)
			const SeraBuf = SeraDeltaSerialize(SeraSchema, Value)
			const SeraDes = Test(`Sera {Label} Deserialize`, function()
				SeraDeltaDeserialize(SeraSchema, SeraBuf)
			end, Iter)
			const SeraRound = Test(`Sera {Label} RoundTrip`, function()
				SeraDeltaDeserialize(SeraSchema, SeraDeltaSerialize(SeraSchema, Value))
			end, Iter)

			RecordSerDesTotal(DeltaTotals, SeraSer, SeraDes, SeraRound, VSSer, VSDes, VSRound)
			task.wait()
		end
	end

	-- Push
	do
		const Dest = buffer.create(PushBufferSize)

		for _, Count in PushFieldCounts do
			const SeraSchema = MakeSeraU8Schema(Count)
			const VSSchema = MakeVSU8Schema(Count)
			const VSSchemaPush = VSSchema.Push
			const Value = MakeU8StructValue(Count)
			const Label = `Push Schema ({Count} fields)`

			Section(Label)
			const VSPushResult = Test(`VS {Label}`, function()
				VSSchemaPush(Value, Dest, 0)
			end, Iter)
			const SeraPushResult = Test(`Sera {Label}`, function()
				SeraPush(SeraSchema, Value, Dest, 0)
			end, Iter)
			RecordAvg(PushTotals, SeraPushResult.Avg, VSPushResult.Avg)
			task.wait()
		end

		for _, Count in DeltaFieldCounts do
			const SeraSchema = MakeSeraU8Schema(Count)
			const VSSchema = MakeVSU8Schema(Count)
			const VSDeltaPush = VSSchema.DeltaPush

			local Cases = {
				{ `DeltaPush ({Count} fields, all present)`, MakeDeltaValueAll(Count) },
				{ `DeltaPush ({Count} fields, 1 missing)`, MakeDeltaValueMissingOne(Count) },
				{ `DeltaPush ({Count} fields, only 1 present)`, MakeDeltaValueOnlyOne(Count) },
			}

			for _, Case in Cases do
				const Label = Case[1]
				const Value = Case[2]

				Section(Label)
				const VSPushResult = Test(`VS {Label}`, function()
					VSDeltaPush(Dest, Value, 0)
				end, Iter)
				const SeraPushResult = Test(`Sera {Label}`, function()
					SeraDeltaPush(SeraSchema, Value, Dest, 0)
				end, Iter)
				RecordAvg(PushTotals, SeraPushResult.Avg, VSPushResult.Avg)
				task.wait()
			end
		end
	end

	if Log then
		PrintResults(Iter)
		PrintOverall("PRIMITIVES OVERALL (avg across scenarios)", PrimitiveTotals)
		PrintOverall("SCHEMAS OVERALL (avg across scenarios)", SchemaTotals)
		PrintOverall("DELTAS OVERALL (avg across scenarios)", DeltaTotals)
		PrintPushOverall("PUSH OVERALL (avg across scenarios)", PushTotals)
	end

	return table.clone(Results)
end

return Comparator

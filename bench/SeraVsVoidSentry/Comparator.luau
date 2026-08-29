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

const function MakeVSU8Struct(Count: number): any
	local Tbl: { [string]: any } = {}
	for i = 1, Count do
		Tbl[MakeFieldName(i)] = VSTypes.U8
	end
	return VSTypes.Struct(Tbl)
end

const function MakeVSU8DeltaStruct(Count: number): any
	local Tbl: { [string]: any } = {}
	for i = 1, Count do
		Tbl[MakeFieldName(i)] = VSTypes.U8
	end
	return VSTypes.DeltaStruct(Tbl)
end

const function Comparator(Log: boolean?, Iterations: number?): BenchTypes.Results
	table.clear(Results)
	const Iter = Iterations or DefaultIterations

	const VSSerialize = VoidSentryUltimate.Serialize
	const VSDeserialize = VoidSentryUltimate.Deserialize
	const VSPush = VoidSentryUltimate.Push
	const SeraSerialize = Sera.Serialize
	const SeraDeserialize = Sera.Deserialize
	const SeraPush = Sera.Push
	const SeraDeltaSerialize = Sera.DeltaSerialize
	const SeraDeltaDeserialize = Sera.DeltaDeserialize
	const SeraDeltaPush = Sera.DeltaPush

	const PrimitiveTotals = NewCategoryTotals()
	const StructTotals = NewCategoryTotals()
	const DeltaTotals = NewCategoryTotals()
	const PushTotals = NewAvgPair()

	const function BenchPaired(
		Cat: CategoryTotals,
		Name: string,
		SeraSchema: any,
		SeraValue: { [string]: any },
		VSSchema: VoidSentryUltimate.SerdesNode<any>,
		VSValue: any,
		SeraSerFn: (any, any) -> any,
		SeraDesFn: (any, any) -> any
	)
		const SeraSer = Test(`Sera {Name} Serialize`, function()
			SeraSerFn(SeraSchema, SeraValue)
		end, Iter)

		const SeraBuf = assert(SeraSerFn(SeraSchema, SeraValue))
		const SeraDes = Test(`Sera {Name} Deserialize`, function()
			SeraDesFn(SeraSchema, SeraBuf)
		end, Iter)

		const SeraRound = Test(`Sera {Name} RoundTrip`, function()
			SeraDesFn(SeraSchema, assert(SeraSerFn(SeraSchema, SeraValue)))
		end, Iter)

		const VSSer = Test(`VS {Name} Serialize`, function()
			VSSerialize(VSSchema, VSValue)
		end, Iter)

		const VSBuf = VSSerialize(VSSchema, VSValue)
		const VSDes = Test(`VS {Name} Deserialize`, function()
			VSDeserialize(VSSchema, VSBuf)
		end, Iter)

		const VSRound = Test(`VS {Name} RoundTrip`, function()
			VSDeserialize(VSSchema, VSSerialize(VSSchema, VSValue))
		end, Iter)

		RecordSerDesTotal(Cat, SeraSer, SeraDes, SeraRound, VSSer, VSDes, VSRound)
	end

	-- Sera only serializes through schemas; wrap each primitive in a single field.
	const function BenchPrimitive(Name: string, SeraType: any, VSSchema: VoidSentryUltimate.SerdesNode<any>, Value: any)
		BenchPaired(
			PrimitiveTotals,
			Name,
			Sera.Schema({ v = SeraType }),
			{ v = Value },
			VSSchema,
			Value,
			SeraSerialize,
			SeraDeserialize
		)
	end

	const function BenchStruct(Name: string, Count: number)
		const Value = MakeU8StructValue(Count)
		BenchPaired(
			StructTotals,
			Name,
			MakeSeraU8Schema(Count),
			Value,
			MakeVSU8Struct(Count),
			Value,
			SeraSerialize,
			SeraDeserialize
		)
	end

	const function BenchDelta(Name: string, SeraSchema: any, VSSchema: VoidSentryUltimate.SerdesNode<any>, Value: { [string]: any })
		BenchPaired(DeltaTotals, Name, SeraSchema, Value, VSSchema, Value, SeraDeltaSerialize, SeraDeltaDeserialize)
	end

	const function BenchPush(
		Name: string,
		SeraSchema: any,
		VSSchema: VoidSentryUltimate.SerdesNode<any>,
		Value: { [string]: any },
		Dest: buffer,
		UseDelta: boolean
	)
		const SeraPushFn = if UseDelta then SeraDeltaPush else SeraPush
		const SeraPushResult = Test(`Sera {Name} Push`, function()
			SeraPushFn(SeraSchema, Value, Dest, 0)
		end, Iter)

		const VSPushResult = Test(`VS {Name} Push`, function()
			VSPush(VSSchema, Value, Dest, 0)
		end, Iter)

		-- Push has no deserialize; one metric only.
		RecordAvg(PushTotals, SeraPushResult.Avg, VSPushResult.Avg)
	end

	const TestVector = Vector3.new(1, 2, 3)
	const TestCFrame = CFrame.new(1, 2, 3) * CFrame.Angles(0.5, 1, 0.25)

	Section("Number Types")
	BenchPrimitive("U8", Sera.Uint8, VSTypes.U8, 42)
	task.wait()
	BenchPrimitive("I8", Sera.Int8, VSTypes.I8, -42)
	task.wait()
	BenchPrimitive("U16", Sera.Uint16, VSTypes.U16, 42)
	task.wait()
	BenchPrimitive("I16", Sera.Int16, VSTypes.I16, -42)
	task.wait()
	BenchPrimitive("U32", Sera.Uint32, VSTypes.U32, 42)
	task.wait()
	BenchPrimitive("I32", Sera.Int32, VSTypes.I32, -42)
	task.wait()
	BenchPrimitive("F32", Sera.Float32, VSTypes.F32, 3.14)
	task.wait()
	BenchPrimitive("F64", Sera.Float64, VSTypes.F64, 3.14)
	task.wait()

	Section("Other Primitives")
	BenchPrimitive("Bool", Sera.Boolean, VSTypes.Bool, true)
	BenchPrimitive("String8 (1 char)", Sera.String8, VSTypes.String8, "a")
	BenchPrimitive("String8 (10 chars)", Sera.String8, VSTypes.String8, "aaaaaaaaaa")
	BenchPrimitive("String8 (100 chars)", Sera.String8, VSTypes.String8, ("a"):rep(100))
	BenchPrimitive("String16 (100 chars)", Sera.String16, VSTypes.String, ("a"):rep(100))
	task.wait()

	Section("Vector Types")
	BenchPaired(
		PrimitiveTotals,
		"Vector3",
		Sera.Schema({ v = Sera.Vector3 }),
		{ v = TestVector },
		VSTypes.Vector,
		TestVector,
		SeraSerialize,
		SeraDeserialize
	)
	task.wait()

	Section("CFrame Types")
	BenchPaired(
		PrimitiveTotals,
		"CFrame",
		Sera.Schema({ v = Sera.CFrame }),
		{ v = TestCFrame },
		VSTypes.CFrame,
		TestCFrame,
		SeraSerialize,
		SeraDeserialize
	)
	-- Both are 28-byte compressed rotations (axis-angle vs quaternion).
	BenchPaired(
		PrimitiveTotals,
		"LossyCFrame/QCFrame",
		Sera.Schema({ v = Sera.LossyCFrame }),
		{ v = TestCFrame },
		VSTypes.QCFrame,
		TestCFrame,
		SeraSerialize,
		SeraDeserialize
	)
	task.wait()

	Section("Struct Types")
	BenchStruct("Struct (1 field)", 1)
	task.wait()
	BenchStruct("Struct (10 fields)", 10)
	task.wait()
	BenchStruct("Struct (100 fields)", 100)
	task.wait()

	Section("Delta Struct Types")
	for _, Count in DeltaFieldCounts do
		const SeraSchema = MakeSeraU8Schema(Count)
		const VSSchema = MakeVSU8DeltaStruct(Count)

		BenchDelta(`Delta ({Count} fields, all present)`, SeraSchema, VSSchema, MakeDeltaValueAll(Count))
		task.wait()
		BenchDelta(`Delta ({Count} fields, 1 missing)`, SeraSchema, VSSchema, MakeDeltaValueMissingOne(Count))
		task.wait()
		BenchDelta(`Delta ({Count} fields, only 1 present)`, SeraSchema, VSSchema, MakeDeltaValueOnlyOne(Count))
		task.wait()
	end

	Section("Push Types")
	do
		const Dest = buffer.create(PushBufferSize)
		for _, Count in PushFieldCounts do
			const Value = MakeU8StructValue(Count)
			BenchPush(`Push Struct ({Count} fields)`, MakeSeraU8Schema(Count), MakeVSU8Struct(Count), Value, Dest, false)
			task.wait()
		end

		for _, Count in DeltaFieldCounts do
			const SeraSchema = MakeSeraU8Schema(Count)
			const VSSchema = MakeVSU8DeltaStruct(Count)

			BenchPush(
				`DeltaPush ({Count} fields, all present)`,
				SeraSchema,
				VSSchema,
				MakeDeltaValueAll(Count),
				Dest,
				true
			)
			task.wait()
			BenchPush(
				`DeltaPush ({Count} fields, 1 missing)`,
				SeraSchema,
				VSSchema,
				MakeDeltaValueMissingOne(Count),
				Dest,
				true
			)
			task.wait()
			BenchPush(
				`DeltaPush ({Count} fields, only 1 present)`,
				SeraSchema,
				VSSchema,
				MakeDeltaValueOnlyOne(Count),
				Dest,
				true
			)
			task.wait()
		end
	end

	if Log then
		PrintResults(Iter)
		PrintOverall("PRIMITIVES OVERALL (avg across scenarios)", PrimitiveTotals)
		PrintOverall("STRUCTS OVERALL (avg across scenarios)", StructTotals)
		PrintOverall("DELTAS OVERALL (avg across scenarios)", DeltaTotals)
		PrintPushOverall("PUSH OVERALL (avg across scenarios)", PushTotals)
	end

	return table.clone(Results)
end

return Comparator

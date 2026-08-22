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

const function Comparator(Log: boolean?, Iterations: number?): BenchTypes.Results
	table.clear(Results)
	const Iter = Iterations or DefaultIterations

	const VSSerialize = VoidSentryUltimate.Serialize
	const VSDeserialize = VoidSentryUltimate.Deserialize
	const SeraSerialize = Sera.Serialize
	const SeraDeserialize = Sera.Deserialize

	const function BenchSera(Name: string, Schema: any, Value: { [string]: any })
		Test(`Sera {Name} Serialize`, function()
			SeraSerialize(Schema, Value)
		end, Iter)

		const Buf = assert(SeraSerialize(Schema, Value))
		Test(`Sera {Name} Deserialize`, function()
			SeraDeserialize(Schema, Buf)
		end, Iter)

		Test(`Sera {Name} RoundTrip`, function()
			SeraDeserialize(Schema, assert(SeraSerialize(Schema, Value)))
		end, Iter)
	end

	const function BenchVS(Name: string, Schema: VoidSentryUltimate.SerdesNode<any>, Value: any)
		Test(`VS {Name} Serialize`, function()
			VSSerialize(Schema, Value)
		end, Iter)

		const Buf = VSSerialize(Schema, Value)
		Test(`VS {Name} Deserialize`, function()
			VSDeserialize(Schema, Buf)
		end, Iter)

		Test(`VS {Name} RoundTrip`, function()
			VSDeserialize(Schema, VSSerialize(Schema, Value))
		end, Iter)
	end

	-- Sera only serializes through schemas; wrap each primitive in a single field.
	const function BenchPrimitive(Name: string, SeraType: any, VSSchema: VoidSentryUltimate.SerdesNode<any>, Value: any)
		BenchSera(Name, Sera.Schema({ v = SeraType }), { v = Value })
		BenchVS(Name, VSSchema, Value)
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
	BenchSera("Vector3", Sera.Schema({ v = Sera.Vector3 }), { v = TestVector })
	BenchVS("Vector3", VSTypes.Vector, TestVector)
	task.wait()

	Section("CFrame Types")
	BenchSera("CFrame", Sera.Schema({ v = Sera.CFrame }), { v = TestCFrame })
	BenchVS("CFrame", VSTypes.CFrame, TestCFrame)
	-- Both are 28-byte compressed rotations (axis-angle vs quaternion).
	BenchSera("LossyCFrame", Sera.Schema({ v = Sera.LossyCFrame }), { v = TestCFrame })
	BenchVS("QCFrame", VSTypes.QCFrame, TestCFrame)
	task.wait()

	Section("Struct Types")
	do
		const Value1 = MakeU8StructValue(1)
		BenchSera("Struct (1 field)", MakeSeraU8Schema(1), Value1)
		BenchVS("Struct (1 field)", MakeVSU8Struct(1), Value1)
	end
	task.wait()
	do
		const Value10 = MakeU8StructValue(10)
		BenchSera("Struct (10 fields)", MakeSeraU8Schema(10), Value10)
		BenchVS("Struct (10 fields)", MakeVSU8Struct(10), Value10)
	end
	task.wait()
	do
		const Value100 = MakeU8StructValue(100)
		BenchSera("Struct (100 fields)", MakeSeraU8Schema(100), Value100)
		BenchVS("Struct (100 fields)", MakeVSU8Struct(100), Value100)
	end

	if Log then
		PrintResults(Iter)
	end

	return table.clone(Results)
end

return Comparator

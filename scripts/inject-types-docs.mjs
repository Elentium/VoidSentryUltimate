import fs from "fs";
import path from "path";
import { fileURLToPath } from "url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const targetPath = path.join(
	__dirname,
	"..",
	"packages",
	"voidsentryultimate",
	"VoidSentryUltimate.luau",
);

const props = [
	["I8", "Primitives", "Signed 8-bit integer. 1 byte.", "SerdesNode<number>"],
	["U8", "Primitives", "Unsigned 8-bit integer. 1 byte.", "SerdesNode<number>"],
	["U16", "Primitives", "Unsigned 16-bit integer. 2 bytes.", "SerdesNode<number>"],
	["I16", "Primitives", "Signed 16-bit integer. 2 bytes.", "SerdesNode<number>"],
	["U32", "Primitives", "Unsigned 32-bit integer. 4 bytes.", "SerdesNode<number>"],
	["I32", "Primitives", "Signed 32-bit integer. 4 bytes.", "SerdesNode<number>"],
	["F32", "Primitives", "IEEE float. 4 bytes.", "SerdesNode<number>"],
	["F64", "Primitives", "IEEE double. 8 bytes.", "SerdesNode<number>"],
	["String", "Special", "UTF-8 string with a `u16` byte-length prefix.", "SerdesNode<string>"],
	["String8", "Special", "UTF-8 string with a `u8` byte-length prefix.", "SerdesNode<string>"],
	["Vector", "Vectors", "`Vector3` with three `f32` components. 12 bytes.", "SerdesNode<Vector3>"],
	["F16", "Primitives", "Half-precision float. 2 bytes. Lossy.", "SerdesNode<number>"],
	["F24", "Primitives", "24-bit float. 3 bytes. Lossy.", "SerdesNode<number>"],
	["U24", "Primitives", "Unsigned 24-bit integer. 3 bytes.", "SerdesNode<number>"],
	["I24", "Primitives", "Signed 24-bit integer. 3 bytes.", "SerdesNode<number>"],
	["VectorF24", "Vectors", "`Vector3` with three `f24` components. 9 bytes.", "SerdesNode<Vector3>"],
	["VectorF16", "Vectors", "`Vector3` with three `f16` components. 6 bytes.", "SerdesNode<Vector3>"],
	["VectorU16", "Vectors", "`Vector3` with three `u16` components. 6 bytes.", "SerdesNode<Vector3>"],
	["VectorI16", "Vectors", "`Vector3` with three `i16` components. 6 bytes.", "SerdesNode<Vector3>"],
	["Color3", "Roblox", "RGB channels as three bytes. 3 bytes.", "SerdesNode<Color3>", "Color3Node"],
	["VectorU8", "Vectors", "`Vector3` with three `u8` components. 3 bytes.", "SerdesNode<Vector3>"],
	["VectorI8", "Vectors", "`Vector3` with three `i8` components. 3 bytes.", "SerdesNode<Vector3>"],
	["VectorU24", "Vectors", "`Vector3` with three `u24` components. 9 bytes.", "SerdesNode<Vector3>"],
	["VectorI24", "Vectors", "`Vector3` with three `i24` components. 9 bytes.", "SerdesNode<Vector3>"],
	["Vector2", "Vectors", "`Vector2` with two `f32` components. 8 bytes.", "SerdesNode<Vector2>", "Vector2Node"],
	["Vector2F24", "Vectors", "`Vector2` with two `f24` components. 6 bytes.", "SerdesNode<Vector2>"],
	["Vector2F16", "Vectors", "`Vector2` with two `f16` components. 4 bytes.", "SerdesNode<Vector2>"],
	["Vector2U16", "Vectors", "`Vector2` with two `u16` components. 4 bytes.", "SerdesNode<Vector2>"],
	["Vector2I16", "Vectors", "`Vector2` with two `i16` components. 4 bytes.", "SerdesNode<Vector2>"],
	["Vector2U8", "Vectors", "`Vector2` with two `u8` components. 2 bytes.", "SerdesNode<Vector2>"],
	["Vector2I8", "Vectors", "`Vector2` with two `i8` components. 2 bytes.", "SerdesNode<Vector2>"],
	["Vector2U24", "Vectors", "`Vector2` with two `u24` components. 6 bytes.", "SerdesNode<Vector2>"],
	["Vector2I24", "Vectors", "`Vector2` with two `i24` components. 6 bytes.", "SerdesNode<Vector2>"],
	["UDim2", "Roblox", "Full `UDim2` as four `f32` values. 16 bytes.", "SerdesNode<UDim2>", "UDim2Node"],
	["UDim2Scale", "Roblox", "Two `f32` scale components. 8 bytes.", "SerdesNode<UDim2>"],
	["UDim2Offset", "Roblox", "Two `f32` offset components. 8 bytes.", "SerdesNode<UDim2>"],
	["UDim2OffsetI16", "Roblox", "Two `i16` offset components. 4 bytes.", "SerdesNode<UDim2>"],
	["UDim2ScaleF24", "Roblox", "Two `f24` scale components. 6 bytes.", "SerdesNode<UDim2>"],
	["Bool", "Primitives", "Boolean stored as one byte (`0` or `1`).", "SerdesNode<boolean>"],
	["BoolPacked", "Special", "Eight booleans packed into 1 byte.", "SerdesNode<{ boolean }>"],
	["Buffer", "Special", "Buffer with a `u16` byte-length prefix.", "SerdesNode<buffer>"],
	["Buffer8", "Special", "Buffer with a `u8` byte-length prefix.", "SerdesNode<buffer>"],
	["Buffer24", "Special", "Buffer with a `u24` byte-length prefix.", "SerdesNode<buffer>"],
	["Instance", "Roblox", "Instance reference as a `u16` `_VSID`. 2 bytes.", "SerdesNode<Instance>", "InstanceNode"],
	["Instance24", "Roblox", "Instance reference as a `u24` `_VSID`. 3 bytes.", "SerdesNode<Instance>"],
	["CFrame", "Roblox", "Position plus rotation matrix (`12 × f32`). 48 bytes.", "SerdesNode<CFrame>", "CFrameNode"],
	["QCFrame", "Roblox", "Position plus quaternion (`7 × f32`). 28 bytes.", "SerdesNode<CFrame>"],
	["CFrameF24", "Roblox", "Rotation matrix with `f24` components. 36 bytes.", "SerdesNode<CFrame>"],
	["CFrameF16", "Roblox", "Rotation matrix with `f16` components. 24 bytes.", "SerdesNode<CFrame>"],
	["QCFrameF24", "Roblox", "Quaternion CFrame with `f24` components. 21 bytes.", "SerdesNode<CFrame>"],
	["QCFrameF16", "Roblox", "Quaternion CFrame with `f16` components. 14 bytes.", "SerdesNode<CFrame>"],
];

const functions = [
	[
		"StringFixed",
		"Special",
		"Fixed-length UTF-8 string with no length prefix.",
		["length number -- Exact byte length on the wire."],
		"SerdesNode<string>",
	],
	[
		"Array",
		"Collections",
		"Array with a `u16` element-count prefix.",
		["node SerdesNode<T> -- Element schema."],
		"SerdesNode<{ T }>",
	],
	[
		"Array8",
		"Collections",
		"Array with a `u8` element-count prefix.",
		["node SerdesNode<T> -- Element schema."],
		"SerdesNode<{ T }>",
	],
	[
		"Array24",
		"Collections",
		"Array with a `u24` element-count prefix.",
		["node SerdesNode<T> -- Element schema."],
		"SerdesNode<{ T }>",
	],
	[
		"Struct",
		"Collections",
		"Struct schema. Field names are sorted lexicographically on the wire.",
		["fields {[string]: SerdesNode<any>} -- Field schemas keyed by name."],
		"SerdesNode<any>",
	],
	[
		"Map",
		"Collections",
		"Map with a `u16` entry-count prefix.",
		[
			"keyNode SerdesNode<K> -- Key schema.",
			"valueNode SerdesNode<V> -- Value schema.",
		],
		"SerdesNode<{ [K]: V }>",
	],
	[
		"Map8",
		"Collections",
		"Map with a `u8` entry-count prefix.",
		[
			"keyNode SerdesNode<K> -- Key schema.",
			"valueNode SerdesNode<V> -- Value schema.",
		],
		"SerdesNode<{ [K]: V }>",
	],
	[
		"Map24",
		"Collections",
		"Map with a `u24` entry-count prefix.",
		[
			"keyNode SerdesNode<K> -- Key schema.",
			"valueNode SerdesNode<V> -- Value schema.",
		],
		"SerdesNode<{ [K]: V }>",
	],
	[
		"ArrayFixed",
		"Collections",
		"Fixed-length array with no count prefix.",
		[
			"node SerdesNode<T> -- Element schema.",
			"length number -- Exact element count.",
		],
		"SerdesNode<{ T }>",
	],
	[
		"MapFixed",
		"Collections",
		"Fixed-length map with no count prefix.",
		[
			"keyNode SerdesNode<K> -- Key schema.",
			"valueNode SerdesNode<V> -- Value schema.",
			"length number -- Exact entry count.",
		],
		"SerdesNode<{ [K]: V }>",
	],
	[
		"BufferFixed",
		"Special",
		"Fixed-length buffer with no length prefix.",
		["length number -- Exact byte length on the wire."],
		"SerdesNode<buffer>",
	],
	[
		"Optional",
		"Collections",
		"Optional value prefixed by a one-byte presence flag.",
		["node SerdesNode<T> -- Inner schema."],
		"SerdesNode<T?>",
	],
	[
		"SerInstance",
		"Roblox",
		"Serializes selected properties from an existing instance.",
		[
			"className string -- Instance class name.",
			"schema {[string]: SerdesNode<any>} -- Property schemas keyed by name.",
		],
		"SerdesNode<Instance>",
	],
	[
		"Enum",
		"Roblox",
		"Enum item stored as a `u16` value.",
		["enumType Enum -- Enum to serialize."],
		"SerdesNode<EnumItem>",
		"EnumNode",
	],
	[
		"Enum8",
		"Roblox",
		"Enum item stored as a `u8` value.",
		["enumType Enum -- Enum to serialize."],
		"SerdesNode<EnumItem>",
	],
];

function propBlock(name, tag, desc, luaType) {
	return [
		`--- ${desc}`,
		"--- @within Types",
		`--- @tag ${tag}`,
		`--- @prop ${name} ${luaType}`,
	].join("\n");
}

function functionBlock(name, tag, desc, params, ret, luaName = name) {
	const lines = [
		`--- ${desc}`,
		"--- @within Types",
		`--- @tag ${tag}`,
		`--- @function ${name}`,
	];
	for (const param of params) {
		lines.push(`--- @param ${param}`);
	}
	lines.push(`--- @return ${ret}`);
	return lines.join("\n");
}

function insertBefore(lines, index, block) {
	if (lines[index - 1]?.includes(`@prop ${block.match(/@prop (\w+)/)?.[1]}`)) {
		return false;
	}
	if (lines[index - 1]?.includes("@within Types")) {
		return false;
	}
	lines.splice(index, 0, block, "");
	return true;
}

let source = fs.readFileSync(targetPath, "utf8");
let lines = source.split("\n");
let inserted = 0;

if (!source.includes("--- @class Types")) {
	const typesIndex = lines.findIndex((line) => line === "const Types = {}");
	if (typesIndex === -1) {
		throw new Error("Could not find Types table declaration");
	}
	lines.splice(
		typesIndex,
		0,
		"--- Schema type nodes from `VoidSentryUltimate.Types`.",
		"--- @class Types",
	);
	inserted += 1;
}

for (const [name, tag, desc, luaType, constName = name] of props) {
	const pattern = new RegExp(`^const ${constName}: `);
	const index = lines.findIndex((line) => pattern.test(line));
	if (index === -1) {
		throw new Error(`Could not find property node ${constName}`);
	}
	if (insertBefore(lines, index, propBlock(name, tag, desc, luaType))) {
		inserted += 1;
	}
}

for (const [name, tag, desc, params, ret, luaName = name] of functions) {
	const pattern = new RegExp(`^const function ${luaName}[<(]`);
	const index = lines.findIndex((line) => pattern.test(line));
	if (index === -1) {
		throw new Error(`Could not find function node ${luaName}`);
	}
	if (insertBefore(lines, index, functionBlock(name, tag, desc, params, ret, luaName))) {
		inserted += 1;
	}
}

fs.writeFileSync(targetPath, lines.join("\n"));
console.log(`Injected ${inserted} Types doc block(s) into VoidSentryUltimate.luau`);

declare namespace VoidSentryUltimate {
	export type SerdesNode<T> = {
		readonly _T: T
	}

	export type Infer<T> = T extends SerdesNode<infer U> ? U : never

	export type StructOf<T extends { readonly [key: string]: SerdesNode<unknown> }> = {
		[K in keyof T]: Infer<T[K]>
	}

	export type DeltaStructOf<T extends { readonly [key: string]: SerdesNode<unknown> }> = {
		[K in keyof T]?: Infer<T[K]>
	}

	export interface Schema<T> {
		readonly Serialize: (data: T) => buffer
		readonly SerializeWithOffset: (data: T, offset: number) => buffer
		readonly Deserialize: (buf: buffer) => LuaTuple<[T, number]>
		readonly DeserializeWithOffset: (buf: buffer, offset: number) => LuaTuple<[T, number]>
		readonly Push: (data: T, buf: buffer, offset?: number) => number
		readonly DeltaSerialize: (data: DeltaStructOf<{ readonly [key: string]: SerdesNode<unknown> }>, offset?: number) => buffer
		readonly DeltaDeserialize: (
			buf: buffer,
			offset?: number,
		) => LuaTuple<[DeltaStructOf<{ readonly [key: string]: SerdesNode<unknown> }>, number]>
		readonly DeltaPush: (
			buf: buffer,
			data: DeltaStructOf<{ readonly [key: string]: SerdesNode<unknown> }>,
			offset: number,
		) => number
	}

	export type Dictionary<K, V> = { [P in Extract<K, string | number>]: V }

	export type BoolPacked = [
		boolean,
		boolean,
		boolean,
		boolean,
		boolean,
		boolean,
		boolean,
		boolean,
	]

	/** Enum item values from an `Enum.*` object (excludes helper methods). */
	export type EnumItemsOf<E> = {
		[K in keyof E]: E[K] extends EnumItem ? E[K] : never
	}[keyof E]

	export interface Types {
		readonly U8: SerdesNode<number>
		readonly I8: SerdesNode<number>
		readonly U16: SerdesNode<number>
		readonly I16: SerdesNode<number>
		readonly U24: SerdesNode<number>
		readonly I24: SerdesNode<number>
		readonly U32: SerdesNode<number>
		readonly I32: SerdesNode<number>
		readonly F16: SerdesNode<number>
		readonly F24: SerdesNode<number>
		readonly F32: SerdesNode<number>
		readonly F64: SerdesNode<number>

		readonly Bool: SerdesNode<boolean>
		readonly BoolPacked: SerdesNode<BoolPacked>

		readonly String: SerdesNode<string>
		readonly String8: SerdesNode<string>
		readonly StringFixed: (length: number) => SerdesNode<string>

		readonly Buffer: SerdesNode<buffer>
		readonly Buffer8: SerdesNode<buffer>
		readonly Buffer24: SerdesNode<buffer>
		readonly BufferFixed: (length: number) => SerdesNode<buffer>

		readonly Vector: SerdesNode<Vector3>
		readonly VectorF16: SerdesNode<Vector3>
		readonly VectorF24: SerdesNode<Vector3>
		readonly VectorU8: SerdesNode<Vector3>
		readonly VectorI8: SerdesNode<Vector3>
		readonly VectorU16: SerdesNode<Vector3>
		readonly VectorI16: SerdesNode<Vector3>
		readonly VectorU24: SerdesNode<Vector3>
		readonly VectorI24: SerdesNode<Vector3>

		readonly Vector2: SerdesNode<Vector2>
		readonly Vector2F16: SerdesNode<Vector2>
		readonly Vector2F24: SerdesNode<Vector2>
		readonly Vector2U8: SerdesNode<Vector2>
		readonly Vector2I8: SerdesNode<Vector2>
		readonly Vector2U16: SerdesNode<Vector2>
		readonly Vector2I16: SerdesNode<Vector2>
		readonly Vector2U24: SerdesNode<Vector2>
		readonly Vector2I24: SerdesNode<Vector2>

		readonly UDim2: SerdesNode<UDim2>
		readonly UDim2Scale: SerdesNode<UDim2>
		readonly UDim2Offset: SerdesNode<UDim2>
		readonly UDim2OffsetI16: SerdesNode<UDim2>
		readonly UDim2ScaleF24: SerdesNode<UDim2>

		readonly CFrame: SerdesNode<CFrame>
		readonly QCFrame: SerdesNode<CFrame>
		readonly CFrameF16: SerdesNode<CFrame>
		readonly CFrameF24: SerdesNode<CFrame>
		readonly QCFrameF16: SerdesNode<CFrame>
		readonly QCFrameF24: SerdesNode<CFrame>

		readonly Color3: SerdesNode<Color3>

		readonly Instance: SerdesNode<Instance>
		readonly Instance24: SerdesNode<Instance>

		readonly Array: <T>(node: SerdesNode<T>) => SerdesNode<Array<T>>
		readonly Array8: <T>(node: SerdesNode<T>) => SerdesNode<Array<T>>
		readonly Array24: <T>(node: SerdesNode<T>) => SerdesNode<Array<T>>
		readonly ArrayFixed: <T>(node: SerdesNode<T>, length: number) => SerdesNode<Array<T>>

		readonly Map: <K, V>(keyNode: SerdesNode<K>, valueNode: SerdesNode<V>) => SerdesNode<Dictionary<K, V>>
		readonly Map8: <K, V>(keyNode: SerdesNode<K>, valueNode: SerdesNode<V>) => SerdesNode<Dictionary<K, V>>
		readonly Map24: <K, V>(keyNode: SerdesNode<K>, valueNode: SerdesNode<V>) => SerdesNode<Dictionary<K, V>>
		readonly MapFixed: <K, V>(
			keyNode: SerdesNode<K>,
			valueNode: SerdesNode<V>,
			length: number,
		) => SerdesNode<Dictionary<K, V>>

		readonly Struct: <T extends { readonly [key: string]: SerdesNode<unknown> }>(
			tbl: T,
		) => SerdesNode<StructOf<T>>

		readonly DeltaStruct: <T extends { readonly [key: string]: SerdesNode<unknown> }>(
			tbl: T,
		) => SerdesNode<DeltaStructOf<T>>

		readonly DeltaStruct16: <T extends { readonly [key: string]: SerdesNode<unknown> }>(
			tbl: T,
		) => SerdesNode<DeltaStructOf<T>>

		readonly Optional: <T>(node: SerdesNode<T>) => SerdesNode<T | undefined>

		readonly SerInstance: {
			<C extends keyof CreatableInstances>(
				className: C,
				schema: { readonly [key: string]: SerdesNode<unknown> },
			): SerdesNode<CreatableInstances[C]>
			(
				className: "",
				schema: { readonly [key: string]: SerdesNode<unknown> },
			): SerdesNode<Instance>
		}

		readonly Enum: <E>(enumType: E) => SerdesNode<EnumItemsOf<E>>
		readonly Enum8: <E>(enumType: E) => SerdesNode<EnumItemsOf<E>>
	}
}

interface VoidSentryUltimate {
	readonly Types: VoidSentryUltimate.Types

	readonly Serialize: <T>(schema: VoidSentryUltimate.SerdesNode<T>, value: T) => buffer
	readonly SerializeWithOffset: <T>(
		schema: VoidSentryUltimate.SerdesNode<T>,
		value: T,
		offset: number,
	) => buffer
	readonly Deserialize: <T>(schema: VoidSentryUltimate.SerdesNode<T>, buf: buffer) => LuaTuple<[T, number]>
	readonly DeserializeWithOffset: <T>(
		schema: VoidSentryUltimate.SerdesNode<T>,
		buf: buffer,
		offset: number,
	) => LuaTuple<[T, number]>
	readonly Push: <T>(
		schema: VoidSentryUltimate.SerdesNode<T>,
		value: T,
		buf: buffer,
		offset?: number,
	) => number
	readonly SetWriteBufferSize: (newSize: number) => void
	readonly Schema: <T extends { readonly [key: string]: SerdesNode<unknown> }>(
		tbl: T,
	) => VoidSentryUltimate.Schema<VoidSentryUltimate.StructOf<T>>
}

declare const VoidSentryUltimate: VoidSentryUltimate
export = VoidSentryUltimate

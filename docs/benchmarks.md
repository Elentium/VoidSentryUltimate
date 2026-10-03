---
sidebar_position: 7
---

# Benchmarks

These numbers come from the in-repo benches under `bench/`, measured on an Apple M4. Absolute times vary by hardware, Studio build, and load; use the ratios and relative ordering as the main takeaway.

Each operation is timed with `BenchHelper`: 50 warm-up calls, then 10 timed batches. Reported **Avg** is mean microseconds per call across those batches.

## VoidSentryUltimate throughput

Source: `benchresults/benchresult.txt`  
Harness: `LuauBench` + `RobloxBench`  
Iterations: **10,000** per timed batch

Values are average microseconds per call (μs). Lower is faster.

### Scalars and strings

| Type | Serialize | Deserialize | RoundTrip |
| --- | ---: | ---: | ---: |
| `U8` | 0.05 | 0.02 | 0.06 |
| `U40` | 0.05 | 0.02 | 0.07 |
| `I40` | 0.05 | 0.02 | 0.07 |
| `U48` | 0.05 | 0.02 | 0.07 |
| `I48` | 0.05 | 0.02 | 0.07 |
| `UInt` (1 byte) | 0.05 | 0.02 | 0.06 |
| `Int` (1 byte) | 0.05 | 0.02 | 0.07 |
| `UInt` (4 byte) | 0.05 | 0.02 | 0.07 |
| `Int` (4 byte) | 0.05 | 0.02 | 0.08 |
| `F32` | 0.05 | 0.02 | 0.06 |
| `F64` | 0.05 | 0.02 | 0.06 |
| `Bool` | 0.05 | 0.02 | 0.06 |
| `String` (100 chars) | 0.08 | 0.06 | 0.14 |

### Vectors, buffers, and Roblox types

| Type | Serialize | Deserialize | RoundTrip |
| --- | ---: | ---: | ---: |
| `Vector` | 0.05 | 0.02 | 0.06 |
| `VectorF16` | 0.07 | 0.03 | 0.09 |
| `BufferFixed` (32b) | 0.07 | 0.05 | 0.12 |
| `Buffer8` (33b payload) | 0.08 | 0.05 | 0.13 |
| `Color3` | 0.09 | 0.05 | 0.08 |
| `UDim2Quant` | 0.07 | 0.04 | 0.10 |
| `CFrame` | 0.09 | 0.05 | 0.14 |
| `QCFrame` | 0.10 | 0.05 | 0.16 |
| `CFrameF16` | 0.14 | 0.08 | 0.23 |
| `CFrameQuantF16` | 0.11 | 0.09 | 0.21 |
| `CFrameQuant8F16` | 0.11 | 0.10 | 0.22 |
| `Instance` | 0.05 | 0.02 | 0.07 |
| `SerInstance` | 0.19 | 0.88 | 1.10 |

### Collections

| Type | Serialize | Deserialize | RoundTrip |
| --- | ---: | ---: | ---: |
| `Array` (10 × `U8`) | 0.14 | 0.14 | 0.29 |
| `Array` (100 × `U8`) | 0.90 | 1.02 | 1.93 |
| `Map` (10 × `U8`→`U8`) | 0.23 | 0.33 | 0.56 |
| `Map` (100 × `U8`→`U8`) | 1.60 | 2.20 | 3.93 |
| `Schema` (10 × `U8`) | 0.18 | 0.32 | 0.51 |
| `Schema` (100 × `U8`) | 1.53 | 2.83 | 4.47 |

Primitive nodes stay near **0.05 μs** serialize and **0.02 μs** deserialize. The 40-bit and 48-bit integer nodes, and both the 1-byte and 4-byte `UInt` / `Int` paths, remain in that range. Cost grows mainly with collection size and with compressed / property-driven types such as `CFrameF16` and `SerInstance`.

## Versus Sera

Source: `benchresults/seravssentryresult.txt`  
Harness: `bench/SeraVsVoidSentry/Comparator.luau`  
Iterations: **10,000** per timed batch

Sera only serializes through schemas. For primitives, vectors, and CFrames the comparator wraps Sera values in a single-field schema, while VoidSentryUltimate uses bare nodes. **Schema** rows compare `Sera.Schema` vs `VoidSentryUltimate.Schema`. **Delta** rows compare `Sera.DeltaSerialize` / `DeltaDeserialize` vs `VoidSentryUltimate.Schema.DeltaSerialize` / `DeltaDeserialize`. **Push** compares `Sera.Push` / `DeltaPush` vs `VoidSentryUltimate.Schema.Push` / `Schema.DeltaPush`.

**Speedup** is `Sera Avg ÷ VoidSentry Avg`. Values above `1.00x` mean VoidSentry was faster.

### Overall (suite averages)

| Category | Serialize | Deserialize | Total / RoundTrip |
| --- | ---: | ---: | ---: |
| Primitives | **1.51x** VS | **2.13x** VS | **1.77x** VS |
| Schemas | **1.25x** VS | **1.01x** VS | **1.09x** VS |
| Deltas | **1.38x** VS | **1.14x** VS | **1.24x** VS |
| Push (avg μs) | VS **1.169** / Sera **1.086** | — | — |

### Floats, vectors, and CFrames

| Operation | Sera (μs) | VoidSentry (μs) | Speedup |
| --- | ---: | ---: | ---: |
| `F32` Serialize | 0.09 | 0.05 | 1.80x |
| `F32` Deserialize | 0.05 | 0.02 | 2.50x |
| `F32` RoundTrip | 0.14 | 0.06 | 2.33x |
| `Vector3` Serialize | 0.09 | 0.05 | 1.80x |
| `Vector3` Deserialize | 0.05 | 0.02 | 2.50x |
| `Vector3` RoundTrip | 0.14 | 0.07 | 2.00x |
| `CFrame` Serialize | 0.14 | 0.10 | 1.40x |
| `CFrame` Deserialize | 0.09 | 0.05 | 1.80x |
| `CFrame` RoundTrip | 0.23 | 0.15 | 1.53x |
| LossyCFrame vs `QCFrame` Serialize | 0.14 | 0.11 | 1.27x |
| LossyCFrame vs `QCFrame` Deserialize | 0.11 | 0.05 | 2.20x |

### Schemas (U8 fields)

| Operation | Sera (μs) | VoidSentry (μs) | Speedup |
| --- | ---: | ---: | ---: |
| 1 field Serialize | 0.09 | 0.06 | 1.50x |
| 1 field Deserialize | 0.05 | 0.05 | 1.00x |
| 10 fields Serialize | 0.23 | 0.18 | 1.28x |
| 10 fields Deserialize | 0.32 | 0.32 | 1.00x |
| 100 fields Serialize | 1.82 | 1.47 | 1.24x |
| 100 fields Deserialize | 2.82 | 2.80 | 1.01x |
| 100 fields RoundTrip | 4.73 | 4.39 | 1.08x |

### Deltas (`Schema.DeltaSerialize` vs Sera delta)

| Operation | Sera (μs) | VoidSentry (μs) | Speedup |
| --- | ---: | ---: | ---: |
| 10 fields, all present Serialize | 0.26 | 0.19 | 1.37x |
| 10 fields, all present Deserialize | 0.36 | 0.33 | 1.09x |
| 100 fields, all present Serialize | 2.20 | 1.60 | 1.38x |
| 100 fields, only 1 present Serialize | 0.09 | 0.07 | 1.29x |
| 255 fields, only 1 present Serialize | 0.09 | 0.06 | 1.50x |

### Push

| Operation | Sera (μs) | VoidSentry (μs) | Speedup |
| --- | ---: | ---: | ---: |
| Schema Push (100 fields) | 1.70 | 1.45 | 1.17x |
| DeltaPush (100 fields, only 1 present) | 0.06 | 0.05 | 1.20x |

### Summary

- **Primitives** are VoidSentry’s clearest win (~**1.5×** serialize, ~**2.1×** deserialize, ~**1.8×** round-trip on the suite averages; bare `F32` / `Vector3` deserialize is **2.5×**).
- **Schemas** stay close: VoidSentry leads serialize (~**1.25×**) and total (~**1.09×**); deserialize is even.
- **Deltas** favor VoidSentry (~**1.38×** serialize, ~**1.14×** deserialize, ~**1.24×** total), including sparse “only 1 present” cases.
- **Push** suite average slightly favors Sera (**1.086 μs** vs **1.169 μs**). Individual rows still vary: 100-field `Schema.Push` and sparse `DeltaPush` favor VoidSentry.
- Prefer schema tables for schema-to-schema comparisons; prefer primitive tables when comparing each library’s natural single-value API.

`LuauBench` also includes a `VoidSentryUltimate.Schema` section for the pure-Luau package.

## Reproducing

```luau
-- VoidSentry-only throughput (Luau subset + Roblox types)
local LuauBench = require(path.to.bench.LuauBench)
local RobloxBench = require(path.to.bench.RobloxBench)
LuauBench(true, 10_000)
RobloxBench(true, 10_000)

-- VoidSentry vs Sera
local Comparator = require(path.to.bench.SeraVsVoidSentry.Comparator)
Comparator(true, 10_000)
```

Raw logs used for this page live in `benchresults/`.

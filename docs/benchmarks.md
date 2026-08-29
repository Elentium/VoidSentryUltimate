---
sidebar_position: 7
---

# Benchmarks

These numbers come from the in-repo benches under `bench/`, measured on an Apple M4. Absolute times vary by hardware, Studio build, and load; use the ratios and relative ordering as the main takeaway.

Each operation is timed with `BenchHelper`: 50 warm-up calls, then 10 timed batches. Reported **Avg** is mean microseconds per call across those batches.

## VoidSentryUltimate throughput

Source: `benchresults/benchresult.txt`  
Harness: `LuauBench` + `RobloxBench`  
Iterations: **100,000** per timed batch

Values are average microseconds per call (μs). Lower is faster.

### Scalars and strings

| Type | Serialize | Deserialize | RoundTrip |
| --- | ---: | ---: | ---: |
| `U8` | 0.049 | 0.019 | 0.066 |
| `F32` | 0.051 | 0.018 | 0.067 |
| `F64` | 0.049 | 0.018 | 0.066 |
| `Bool` | 0.049 | 0.018 | 0.066 |
| `String` (100 chars) | 0.076 | 0.059 | 0.139 |

### Vectors, buffers, and Roblox types

| Type | Serialize | Deserialize | RoundTrip |
| --- | ---: | ---: | ---: |
| `Vector` | 0.052 | 0.018 | 0.069 |
| `VectorF16` | 0.069 | 0.030 | 0.105 |
| `BufferFixed` (32b) | 0.068 | 0.050 | 0.118 |
| `Buffer8` (33b payload) | 0.077 | 0.053 | 0.132 |
| `Color3` | 0.053 | 0.037 | 0.090 |
| `CFrame` | 0.091 | 0.060 | 0.148 |
| `QCFrame` | 0.096 | 0.052 | 0.149 |
| `CFrameF16` | 0.157 | 0.102 | 0.261 |
| `Instance` | 0.055 | 0.020 | 0.075 |
| `SerInstance` | 0.184 | 0.957 | 1.134 |

### Collections

| Type | Serialize | Deserialize | RoundTrip |
| --- | ---: | ---: | ---: |
| `Array` (10 × `U8`) | 0.151 | 0.149 | 0.306 |
| `Array` (100 × `U8`) | 0.971 | 1.044 | 2.006 |
| `Map` (10 × `U8`→`U8`) | 0.261 | 0.343 | 0.636 |
| `Map` (100 × `U8`→`U8`) | 2.018 | 2.223 | 4.473 |
| `Struct` (10 × `U8`) | 0.196 | 0.364 | 0.578 |
| `Struct` (100 × `U8`) | 1.596 | 2.945 | 4.632 |

Primitive nodes stay near **0.05 μs** serialize and **0.02 μs** deserialize. Cost grows mainly with collection size and with compressed / property-driven types such as `CFrameF16` and `SerInstance`.

## Versus Sera

Source: `benchresults/seravssentryresult.txt`  
Harness: `bench/SeraVsVoidSentry/Comparator.luau`  
Iterations: **10,000** per timed batch

Sera only serializes through schemas. For primitives, vectors, and CFrames the comparator wraps Sera values in a single-field schema, while VoidSentryUltimate uses bare nodes. **Struct** rows compare `Sera.Schema` vs `Types.Struct`. **Delta** rows compare `Sera.DeltaSerialize` / `DeltaDeserialize` vs `Types.DeltaStruct`. **Push** compares `Sera.Push` / `DeltaPush` vs `VoidSentryUltimate.Push`.

**Speedup** is `Sera Avg ÷ VoidSentry Avg`. Values above `1.00x` mean VoidSentry was faster.

### Overall (suite averages)

| Category | Serialize | Deserialize | Total / RoundTrip |
| --- | ---: | ---: | ---: |
| Primitives | **1.60x** VS | **2.07x** VS | **2.04x** VS |
| Structs | **1.07x** VS | 1.03x Sera | **1.02x** VS |
| Deltas | **1.21x** VS | **1.01x** VS | **1.10x** VS |
| Push (avg μs) | VS **0.934** / Sera **1.072** | — | — |

### Numbers, bools, and strings

| Operation | Sera (μs) | VoidSentry (μs) | Speedup |
| --- | ---: | ---: | ---: |
| `U8` Serialize | 0.09 | 0.05 | 1.80x |
| `U8` Deserialize | 0.06 | 0.02 | 3.00x |
| `U8` RoundTrip | 0.16 | 0.06 | 2.67x |
| `F64` Serialize | 0.09 | 0.05 | 1.80x |
| `F64` Deserialize | 0.06 | 0.02 | 3.00x |
| `Bool` Serialize | 0.10 | 0.05 | 2.00x |
| `Bool` Deserialize | 0.06 | 0.02 | 3.00x |
| `String8` (100 chars) Serialize | 0.14 | 0.08 | 1.75x |
| `String8` (100 chars) Deserialize | 0.10 | 0.07 | 1.43x |

### Vectors and CFrames

| Operation | Sera (μs) | VoidSentry (μs) | Speedup |
| --- | ---: | ---: | ---: |
| `Vector3` Serialize | 0.10 | 0.06 | 1.67x |
| `Vector3` Deserialize | 0.06 | 0.02 | 3.00x |
| `Vector3` RoundTrip | 0.17 | 0.07 | 2.43x |
| `CFrame` Serialize | 0.14 | 0.09 | 1.56x |
| `CFrame` Deserialize | 0.09 | 0.05 | 1.80x |
| `CFrame` RoundTrip | 0.24 | 0.15 | 1.60x |
| LossyCFrame vs `QCFrame` Serialize | 0.14 | 0.10 | 1.40x |
| LossyCFrame vs `QCFrame` Deserialize | 0.12 | 0.05 | 2.40x |

### Structs (U8 fields)

| Operation | Sera (μs) | VoidSentry (μs) | Speedup |
| --- | ---: | ---: | ---: |
| 1 field Serialize | 0.09 | 0.07 | 1.29x |
| 1 field Deserialize | 0.06 | 0.07 | 0.86x |
| 10 fields Serialize | 0.22 | 0.19 | 1.16x |
| 10 fields Deserialize | 0.36 | 0.38 | 0.95x |
| 100 fields Serialize | 1.65 | 1.58 | 1.04x |
| 100 fields Deserialize | 2.87 | 2.95 | 0.97x |
| 100 fields RoundTrip | 4.82 | 4.76 | 1.01x |

### Deltas (`DeltaStruct` vs Sera delta)

| Operation | Sera (μs) | VoidSentry (μs) | Speedup |
| --- | ---: | ---: | ---: |
| 10 fields, all present Serialize | 0.26 | 0.23 | 1.13x |
| 10 fields, all present Deserialize | 0.39 | 0.41 | 0.95x |
| 100 fields, all present Serialize | 2.23 | 1.87 | 1.19x |
| 100 fields, only 1 present Serialize | 0.10 | 0.07 | 1.43x |
| 255 fields, only 1 present Serialize | 0.10 | 0.08 | 1.25x |

### Push

| Operation | Sera (μs) | VoidSentry (μs) | Speedup |
| --- | ---: | ---: | ---: |
| Struct Push (100 fields) | 1.66 | 1.59 | 1.04x |
| DeltaPush (100 fields, only 1 present) | 0.07 | 0.04 | 1.75x |

### Summary

- **Primitives** are VoidSentry’s clearest win (~**1.6–2.1×** on the suite averages; bare deserialize often ~**3×**).
- **Structs** are near parity: VoidSentry slightly ahead on serialize/total; Sera occasionally edges deserialize.
- **Deltas** favor VoidSentry overall (~**1.21×** serialize, ~**1.10×** total), including sparse “only 1 present” cases after input-key iteration.
- **Push** averages favor VoidSentry (**0.934 μs** vs **1.072 μs**).
- Prefer struct/delta tables for schema-to-schema comparisons; prefer primitive tables when comparing each library’s natural single-value API.

## Reproducing

```luau
-- VoidSentry-only throughput (Luau subset + Roblox types)
local LuauBench = require(path.to.bench.LuauBench)
local RobloxBench = require(path.to.bench.RobloxBench)
LuauBench(true, 100_000)
RobloxBench(true, 100_000)

-- VoidSentry vs Sera
local Comparator = require(path.to.bench.SeraVsVoidSentry.Comparator)
Comparator(true, 10_000)
```

Raw logs used for this page live in `benchresults/`.

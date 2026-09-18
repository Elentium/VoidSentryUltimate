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
| `U8` | 0.06 | 0.02 | 0.08 |
| `F32` | 0.06 | 0.02 | 0.08 |
| `F64` | 0.06 | 0.02 | 0.08 |
| `Bool` | 0.06 | 0.02 | 0.08 |
| `String` (100 chars) | 0.09 | 0.06 | 0.16 |

### Vectors, buffers, and Roblox types

| Type | Serialize | Deserialize | RoundTrip |
| --- | ---: | ---: | ---: |
| `Vector` | 0.06 | 0.02 | 0.08 |
| `VectorF16` | 0.08 | 0.03 | 0.12 |
| `BufferFixed` (32b) | 0.08 | 0.05 | 0.14 |
| `Buffer8` (33b payload) | 0.09 | 0.06 | 0.16 |
| `Color3` | 0.07 | 0.04 | 0.08 |
| `CFrame` | 0.09 | 0.06 | 0.14 |
| `QCFrame` | 0.09 | 0.05 | 0.14 |
| `CFrameF16` | 0.15 | 0.10 | 0.25 |
| `Instance` | 0.05 | 0.02 | 0.07 |
| `SerInstance` | 0.20 | 0.96 | 1.25 |

### Collections

| Type | Serialize | Deserialize | RoundTrip |
| --- | ---: | ---: | ---: |
| `Array` (10 × `U8`) | 0.17 | 0.15 | 0.32 |
| `Array` (100 × `U8`) | 0.94 | 1.03 | 2.05 |
| `Map` (10 × `U8`→`U8`) | 0.25 | 0.35 | 0.63 |
| `Map` (100 × `U8`→`U8`) | 1.98 | 2.32 | 4.36 |
| `Schema` (10 × `U8`) | 0.19 | 0.38 | 0.58 |
| `Schema` (100 × `U8`) | 1.72 | 3.13 | 4.89 |

Primitive nodes stay near **0.06 μs** serialize and **0.02 μs** deserialize. Cost grows mainly with collection size and with compressed / property-driven types such as `CFrameF16` and `SerInstance`.

## Versus Sera

Source: `benchresults/seravssentryresult.txt`  
Harness: `bench/SeraVsVoidSentry/Comparator.luau`  
Iterations: **10,000** per timed batch

Sera only serializes through schemas. For primitives, vectors, and CFrames the comparator wraps Sera values in a single-field schema, while VoidSentryUltimate uses bare nodes. **Schema** rows compare `Sera.Schema` vs `VoidSentryUltimate.Schema`. **Delta** rows compare `Sera.DeltaSerialize` / `DeltaDeserialize` vs `VoidSentryUltimate.Schema.DeltaSerialize` / `DeltaDeserialize`. **Push** compares `Sera.Push` / `DeltaPush` vs `VoidSentryUltimate.Schema.Push` / `Schema.DeltaPush`.

**Speedup** is `Sera Avg ÷ VoidSentry Avg`. Values above `1.00x` mean VoidSentry was faster.

### Overall (suite averages)

| Category | Serialize | Deserialize | Total / RoundTrip |
| --- | ---: | ---: | ---: |
| Primitives | **1.70x** VS | **3.33x** VS | **1.90x** VS |
| Schemas | **1.31x** VS | **1.00x** VS | **1.04x** VS |
| Deltas | **1.44x** VS | **1.13x** VS | **1.27x** VS |
| Push (avg μs) | VS **1.153** / Sera **1.069** | — | — |

### Floats, vectors, and CFrames

| Operation | Sera (μs) | VoidSentry (μs) | Speedup |
| --- | ---: | ---: | ---: |
| `F32` Serialize | 0.08 | 0.05 | 1.60x |
| `F32` Deserialize | 0.06 | 0.01 | 6.00x |
| `F32` RoundTrip | 0.15 | 0.06 | 2.50x |
| `Vector3` Serialize | 0.09 | 0.05 | 1.80x |
| `Vector3` Deserialize | 0.06 | 0.01 | 6.00x |
| `Vector3` RoundTrip | 0.15 | 0.06 | 2.50x |
| `CFrame` Serialize | 0.13 | 0.09 | 1.44x |
| `CFrame` Deserialize | 0.09 | 0.05 | 1.80x |
| `CFrame` RoundTrip | 0.23 | 0.14 | 1.64x |
| LossyCFrame vs `QCFrame` Serialize | 0.15 | 0.09 | 1.67x |
| LossyCFrame vs `QCFrame` Deserialize | 0.22 | 0.05 | 4.40x |

### Schemas (U8 fields)

| Operation | Sera (μs) | VoidSentry (μs) | Speedup |
| --- | ---: | ---: | ---: |
| 1 field Serialize | 0.09 | 0.05 | 1.80x |
| 1 field Deserialize | 0.06 | 0.06 | 1.00x |
| 10 fields Serialize | 0.43 | 0.20 | 2.15x |
| 10 fields Deserialize | 0.56 | 0.56 | 1.00x |
| 100 fields Serialize | 1.77 | 1.49 | 1.19x |
| 100 fields Deserialize | 3.02 | 3.14 | 0.96x |
| 100 fields RoundTrip | 5.01 | 4.56 | 1.10x |

### Deltas (`Schema.DeltaSerialize` vs Sera delta)

| Operation | Sera (μs) | VoidSentry (μs) | Speedup |
| --- | ---: | ---: | ---: |
| 10 fields, all present Serialize | 0.27 | 0.19 | 1.42x |
| 10 fields, all present Deserialize | 0.41 | 0.38 | 1.08x |
| 100 fields, all present Serialize | 2.22 | 1.57 | 1.41x |
| 100 fields, only 1 present Serialize | 0.10 | 0.06 | 1.67x |
| 255 fields, only 1 present Serialize | 0.10 | 0.06 | 1.67x |

### Push

| Operation | Sera (μs) | VoidSentry (μs) | Speedup |
| --- | ---: | ---: | ---: |
| Schema Push (100 fields) | 1.73 | 1.44 | 1.20x |
| DeltaPush (100 fields, only 1 present) | 0.06 | 0.04 | 1.50x |

### Summary

- **Primitives** are VoidSentry’s clearest win (~**1.7×** serialize, ~**3.3×** deserialize, ~**1.9×** round-trip on the suite averages; bare `F32` / `Vector3` deserialize is about **6×**).
- **Schemas** stay close: VoidSentry leads serialize (~**1.31×**) and total (~**1.04×**); deserialize is even.
- **Deltas** favor VoidSentry (~**1.44×** serialize, ~**1.13×** deserialize, ~**1.27×** total), including sparse “only 1 present” cases.
- **Push** suite average slightly favors Sera (**1.069 μs** vs **1.153 μs**). Individual rows still vary: 100-field `Schema.Push` and sparse `DeltaPush` favor VoidSentry.
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

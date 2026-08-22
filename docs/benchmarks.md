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

Sera only serializes through schemas. For primitives, vectors, and CFrames the comparator wraps Sera values in a single-field schema, while VoidSentryUltimate uses bare nodes. **Struct** rows are the fairest same-shape comparison (`Sera.Schema` vs `Types.Struct`).

**Speedup** is `Sera Avg ÷ VoidSentry Avg`. Values above `1.00x` mean VoidSentry was faster.

### Numbers, bools, and strings

| Operation | Sera (μs) | VoidSentry (μs) | Speedup |
| --- | ---: | ---: | ---: |
| `U8` Serialize | 0.09 | 0.05 | 1.80x |
| `U8` Deserialize | 0.06 | 0.02 | 3.00x |
| `U8` RoundTrip | 0.16 | 0.06 | 2.67x |
| `F64` Serialize | 0.09 | 0.05 | 1.80x |
| `F64` Deserialize | 0.06 | 0.02 | 3.00x |
| `Bool` Serialize | 0.09 | 0.05 | 1.80x |
| `Bool` Deserialize | 0.06 | 0.02 | 3.00x |
| `String8` (100 chars) Serialize | 0.14 | 0.08 | 1.75x |
| `String8` (100 chars) Deserialize | 0.10 | 0.06 | 1.67x |

### Vectors and CFrames

| Operation | Sera (μs) | VoidSentry (μs) | Speedup |
| --- | ---: | ---: | ---: |
| `Vector3` Serialize | 0.09 | 0.05 | 1.80x |
| `Vector3` Deserialize | 0.06 | 0.02 | 3.00x |
| `Vector3` RoundTrip | 0.16 | 0.07 | 2.29x |
| `CFrame` Serialize | 0.14 | 0.09 | 1.56x |
| `CFrame` Deserialize | 0.09 | 0.05 | 1.80x |
| `CFrame` RoundTrip | 0.24 | 0.15 | 1.60x |
| LossyCFrame vs `QCFrame` Serialize | 0.14 | 0.10 | 1.40x |
| LossyCFrame vs `QCFrame` Deserialize | 0.12 | 0.05 | 2.40x |

### Structs (U8 fields)

| Operation | Sera (μs) | VoidSentry (μs) | Speedup |
| --- | ---: | ---: | ---: |
| 1 field Serialize | 0.09 | 0.08 | 1.12x |
| 1 field Deserialize | 0.06 | 0.09 | 0.67x |
| 10 fields Serialize | 0.24 | 0.20 | 1.20x |
| 10 fields Deserialize | 0.36 | 0.38 | 0.95x |
| 100 fields Serialize | 1.80 | 1.53 | 1.18x |
| 100 fields Deserialize | 2.87 | 2.94 | 0.98x |
| 100 fields RoundTrip | 4.79 | 4.55 | 1.05x |

### Summary

- Across the paired comparator suite, VoidSentry was faster on most operations (roughly **1.8× median**, **~2× mean** speedup).
- The largest gaps are on **deserialize** of bare primitives, vectors, and CFrames.
- On **multi-field structs**, the libraries are close: VoidSentry tends to win serialize; Sera occasionally edges small-struct deserialize.
- Prefer the struct table when comparing schema-to-schema work; prefer the primitive tables when comparing each library's natural API for single values.

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

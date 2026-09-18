# Changelog

## 1.1.0

- Added `VoidSentryUltimate.Schema` for struct helpers (`Serialize`, `Deserialize`, `Push`, `DeltaSerialize`, `DeltaDeserialize`, `DeltaPush`) aligned with Sera's schema API
- Sera vs VoidSentry benchmarks now compare `Sera.Schema` against `VoidSentryUltimate.Schema`
- Micro optimizations
- Fixed Instance defer fallback issue
- Instance maps are now plain tables (manual cleanup)
- Internal Ser/Des structure rewrite

## 1.0.2
- `Deserialize`, `DeserializeWithOffset`, `Push` now return the cursor

## 1.0.1

- Added `DeltaStruct`, `DeltaStruct16` types
- Micro improvements

## 1.0.0

- Initial release

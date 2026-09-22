# Changelog

## 1.1.1

- Added `UDim2Quant`, `CFrameQuant`, `CFrameQuant8`, `CFrameQuantF16`, `CFrameQuant8F16`, `U40`, `I40`, `U48`, `I48` types
- Improved Serialize API members
- Fixed Docs to show .Schema API and the Schema type
- Added missing micro optimizations

## 1.1.0

- Added `VoidSentryUltimate.Schema` for struct helpers (`Serialize`, `Deserialize`, `Push`, `DeltaSerialize`, `DeltaDeserialize`, `DeltaPush`)
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

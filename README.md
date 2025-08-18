# SpeechWrapper

iOS 26+ の最新 Speech フレームワーク（SpeechAnalyzer, SpeechTranscriber, AssetInventory）を用いた、オンデバイス音声→テキストの薄いファサードです。依存はプロトコルで抽象化し、ユニットテストはモックで完結します。

## 対応環境
- iOS 26 以降
- Swift 6 / Xcode 26

## 使い方（最小）
```swift
import SpeechWrapper

let service = TranscriptionService(
  audioInput: YourAudioInput()
)

let stream = await service.resultStream()
Task { for await r in stream { print(r.text, r.isFinal) } }

try await service.start()
// ... 必要に応じて停止
await service.stop()
```

## 必要権限（アプリ側）
- `NSMicrophoneUsageDescription`

## ビルド / テスト
- ビルド: `swift build`
- テスト: `swift test`

## 既知の制限
- ロケールやモデル選択など高度なオプションは未公開（将来拡張）。
- iOS 実装は SpeechAnalyzer + SpeechTranscriber + AssetInventory を参照。非 iOS 環境では No-op 実装を使用します（テストはモック注入）。

## 参考資料
- https://developer.apple.com/documentation/speech
- https://developer.apple.com/documentation/speech/speechanalyzer
- https://developer.apple.com/documentation/speech/speechtranscriber
- https://developer.apple.com/documentation/speech/assetinventory
- https://developer.apple.com/videos/wwdc2025/

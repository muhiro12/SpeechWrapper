# SpeechWrapper

Thin, testable facade for on-device speech-to-text using Apple’s latest Speech framework modules on iOS 26+: SpeechAnalyzer, SpeechTranscriber, and AssetInventory. Dependencies are abstracted via protocols and unit tests run with mocks (no mic/device required).

## Requirements
- iOS 26+
- Swift 6 / Xcode 26

## Minimal Usage
```swift
import SpeechWrapper

let service = TranscriptionService(
  audioInput: YourAudioInput()
)

let stream = await service.resultStream()
Task { for await r in stream { print(r.text, r.isFinal) } }

try await service.start()
// ... later
await service.stop()
```

## App Permissions
- `NSMicrophoneUsageDescription`

## Build & Test
- Build (iOS Simulator):
  - `xcodebuild -scheme SpeechWrapper -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=26.0' build`
- Test (iOS Simulator):
  - `xcodebuild -scheme SpeechWrapper -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=26.0' -only-testing:SpeechWrapperTests test`

Note: This package targets iOS only; running `swift test` on macOS is not supported.

## Known Limitations
- Advanced options (locale/model selection) are not exposed yet.
- iOS-only implementation wires SpeechAnalyzer + SpeechTranscriber + AssetInventory; non‑iOS builds rely on no-op engine and dependency injection for tests.
- Audio feeding uses an abstraction; converting `AudioChunk` to `AVAudioPCMBuffer` is left to concrete audio input implementations.

## References
- https://developer.apple.com/documentation/speech
- https://developer.apple.com/documentation/speech/speechanalyzer
- https://developer.apple.com/documentation/speech/speechtranscriber
- https://developer.apple.com/documentation/speech/assetinventory
- https://developer.apple.com/videos/wwdc2025/

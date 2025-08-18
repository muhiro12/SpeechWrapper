# SpeechWrapper

Thin, testable facade for on-device speech-to-text using Apple’s latest Speech framework modules on iOS 26+: SpeechAnalyzer, SpeechTranscriber, and AssetInventory. Dependencies are abstracted via protocols and unit tests run with mocks (no mic/device required).

## Requirements
- iOS 26+
- Swift 6 / Xcode 26

## Minimal Usage (Public API)
```swift
import SpeechWrapper

// Simplest: use built-in microphone input
let service = TranscriptionService.usingMicrophone()

// 1) One-shot (async/await): waits for first final result
let final: TranscriptionResult = try await service.transcribeOnce()
print(final.text)

// 2) Streaming (AsyncStream): get real-time partial/final results
let stream = try await service.startStreaming()
Task { for await r in stream { print(r.text, r.isFinal) } }
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

Note: The public API focuses on two clear entry points: `transcribeOnce()` and `startStreaming()`/`stop()`. Internal helpers like `start()` and `resultStream()` are not exposed.

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

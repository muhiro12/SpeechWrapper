# SpeechWrapper

Thin, testable facade for on-device speech-to-text using Apple’s latest Speech framework modules on iOS 26+: SpeechAnalyzer, SpeechTranscriber, and AssetInventory. Dependencies are abstracted via protocols and unit tests run with mocks (no mic/device required).

## Requirements
- iOS 26+
- Swift 6 / Xcode 26

## Minimal Usage (Public API)
Two entrypoints via an instance client, using the built‑in microphone. On iOS 26+, the latest Speech APIs are used; on iOS 17/18, a compatible fallback is used.

```swift
import SpeechWrapper

// Configure once (optional). Defaults: latest API on iOS 26+, cancel throws.
let client = SpeechClient(settings: .init(useLegacy: false, cancelPolicy: .throwError))

// 1) One‑shot: waits and returns the final text (auto endpoint detection)
let text: String = try await client.transcribe()
print(text)

// 2) Streaming: yields partial/final texts; finishes automatically on final
let stream = try await client.stream()
for await text in stream { print(text) }

// Optional: Force legacy (iOS 17/18) path even on iOS 26+
let legacyClient = SpeechClient(settings: .init(useLegacy: true))
let legacyText = try await legacyClient.transcribe()

// Manual stop/cancel with the same API
let c = SpeechClient()
let task = Task { try await c.transcribe() }
// ... later, user taps Stop -> returns latest interim
await c.stop()
let stopped = try await task.value

// Cancel and return empty
let c2 = SpeechClient(settings: .init(cancelPolicy: .returnEmpty))
let t2 = Task { try await c2.transcribe() }
await c2.cancel()
let empty = try await t2.value  // ""
```

## App Permissions
- `NSMicrophoneUsageDescription`

## Build & Test
- Build (iOS Simulator):
  - `xcodebuild -scheme SpeechWrapper -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=26.0' build`
- Test (iOS Simulator):
  - `xcodebuild -scheme SpeechWrapper -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=26.0' -only-testing:SpeechWrapperTests test`

Note: The public API surface is kept minimal with just two functions. All other types are internal.

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

# SpeechWrapper

Thin, testable facade for on-device speech-to-text using Apple’s latest Speech framework modules on iOS 26+: SpeechAnalyzer, SpeechTranscriber, and AssetInventory. Dependencies are abstracted via protocols and unit tests run with mocks (no mic/device required).

## Requirements
- iOS 17+
- Swift 6 / Xcode 26

## Minimal Usage (Public API)
Two entrypoints via an instance client (stream-first design). On iOS 26+, the latest Speech APIs are used; on iOS 17/18, a compatible fallback is used.

```swift
import SpeechWrapper

// Configure once (optional). Defaults: latest API on iOS 26+, cancel throws, locale = .current.
let client = SpeechClient(settings: .init(cancelPolicy: .throwError, useLegacy: false))

// 1) Streaming (primary): yields partial/final texts; does NOT auto-finish on final
let stream = try await client.stream()
for await text in stream { print(text) }

// ... later, user taps Stop to finish
await client.stop()

// Optional: Force legacy (iOS 17/18) path even on iOS 26+
let legacyClient = SpeechClient(settings: .init(useLegacy: true))
let legacyText = try await legacyClient.transcribe()

// (One-shot pattern can be built by the app using Task + stop())
```

### Settings (trailing config; safe defaults)
- `useLegacy`: `false` (default). For development to force iOS 17/18 fallback even on 26+.
- `locale`: `nil` (default) → uses `Locale.current`. Set explicitly, e.g., `Locale(identifier: "ja-JP")`.

## App Permissions
- `NSMicrophoneUsageDescription`

## Build & Test
- Build (iOS Simulator):
  - `xcodebuild -scheme SpeechWrapper -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=26.0' build`
- Test (iOS Simulator):
  - `xcodebuild -scheme SpeechWrapper -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=26.0' -only-testing:SpeechWrapperTests test`

Note: The public API surface is kept minimal with two primary entry points on `SpeechClient`. All other types are internal.

## Known Limitations
- iOS-only implementation wires SpeechAnalyzer + SpeechTranscriber + AssetInventory (26+) or SFSpeechRecognizer (17/18). Non‑iOS builds rely on no-op engine and dependency injection for tests.
- Audio feeding uses an abstraction; converting `AudioChunk` to `AVAudioPCMBuffer` is left to concrete audio input implementations.

## References
- https://developer.apple.com/documentation/speech
- https://developer.apple.com/documentation/speech/speechanalyzer
- https://developer.apple.com/documentation/speech/speechtranscriber
- https://developer.apple.com/documentation/speech/assetinventory
- https://developer.apple.com/videos/wwdc2025/

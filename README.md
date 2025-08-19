# SpeechWrapper

Thin, testable facade for on-device speech-to-text using Apple’s latest Speech framework modules on iOS 26+: SpeechAnalyzer, SpeechTranscriber, and AssetInventory. Dependencies are abstracted via protocols and unit tests run with mocks (no mic/device required).

## Requirements
- iOS 17+
- Swift 6 / Xcode 26

## Minimal Usage (Public API)
Two entrypoints via an instance client, using the built‑in microphone. On iOS 26+, the latest Speech APIs are used; on iOS 17/18, a compatible fallback is used.

```swift
import SpeechWrapper

// Configure once (optional). Defaults: latest API on iOS 26+, cancel throws, locale = .current.
let client = SpeechClient(settings: .init(cancelPolicy: .throwError, useLegacy: false))

// 1) One‑shot: waits and returns the final text (auto endpoint detection)
let text: String = try await client.transcribe()
print(text)

// 2) Streaming: yields partial/final texts; finishes automatically on final
let stream = try await client.stream()
for await text in stream { print(text) }

// Optional: Require explicit user stop (avoid early final on short utterances)
let holdClient = SpeechClient(settings: .init(requireUserStop: true))
let transcribeTask = Task { try await holdClient.transcribe() }
// ... later, user taps Stop
await holdClient.stop()
let heldText = try await transcribeTask.value

// Optional: Force legacy (iOS 17/18) path even on iOS 26+
let legacyClient = SpeechClient(settings: .init(useLegacy: true))
let legacyText = try await legacyClient.transcribe()

// Manual control using a session handle (awaitable wait())
let session = try await client.beginTranscribe()
// ... later, user taps Stop -> returns latest interim
await session.stop()
let stopped = try await session.wait()

// Cancel and return empty
let session2 = try await SpeechClient(settings: .init(cancelPolicy: .returnEmpty)).beginTranscribe()
await session2.cancel()
let empty = try await session2.wait()  // ""
```

### Settings (trailing config)
- `cancelPolicy`: `.throwError` (default) or `.returnEmpty`
- `useLegacy`: `false` (default). For development to force iOS 17/18 fallback even on 26+.
- `locale`: `nil` (default) → uses `Locale.current`. Set explicitly, e.g., `Locale(identifier: "ja-JP")`.
- `requireUserStop`: `false` (default). When `true`, `transcribe()` ignores automatic final and waits for `stop()`.

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

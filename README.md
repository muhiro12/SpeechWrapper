# SpeechWrapper

Thin, testable facade for on-device speech-to-text using Apple’s latest Speech framework modules on iOS 26+: SpeechAnalyzer, SpeechTranscriber, and AssetInventory. Dependencies are abstracted via protocols and unit tests run with mocks (no mic/device required).

## Requirements
- iOS 26+
- Swift 6 / Xcode 26

## Minimal Usage (Public API)
Only two entrypoints are public (as static methods), using the built‑in microphone. On iOS 26+, the latest Speech APIs are used; on iOS 17/18, a compatible fallback is used.

```swift
import SpeechWrapper

// 1) One‑shot: waits and returns the final text
let text: String = try await SpeechClient.transcribe()
print(text)

// 2) Streaming: yields partial/final texts and finishes automatically
let stream = try await SpeechClient.stream()
for await text in stream {
    print(text)
}

// Optional: Force legacy (iOS 17/18) code path even on iOS 26+
let textLegacy: String = try await SpeechClient.transcribe(useLegacy: true)
let streamLegacy = try await SpeechClient.stream(useLegacy: true)
for await text in stream {
    print(text)
}

// 3) Manual control within a single transcribe() call
//    - stop(): user explicitly stops and gets the latest interim text
//    - cancel(): user/system cancels; choose policy to return empty or throw
let control = SpeechClient.Control()
let task = Task { try await SpeechClient.transcribe(control: control) }
// ... later, user taps Stop button
await control.stop()
let stoppedText = try await task.value  // latest interim text

// Cancel with empty string result
let control2 = SpeechClient.Control()
let task2 = Task { try await SpeechClient.transcribe(control: control2, cancelPolicy: .returnEmpty) }
await control2.cancel()
let cancelledAsEmpty = try await task2.value  // ""

// Cancel as error
let control3 = SpeechClient.Control()
let task3 = Task { try await SpeechClient.transcribe(control: control3, cancelPolicy: .throwError) }
await control3.cancel()
do {
    _ = try await task3.value
} catch {
    print(error.localizedDescription)  // TranscriptionError.cancelled
}
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

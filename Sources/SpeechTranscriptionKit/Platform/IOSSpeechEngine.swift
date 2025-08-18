import Foundation

#if os(iOS) && canImport(Speech)
import Speech

@available(iOS 26, *)
final class IOSSpeechEngine: TranscriptionEngine {
    // Intentionally keep usage conservative to compile against iOS 26 SDK.
    // Keep references typed loosely; concrete wiring may vary by SDK.
    private var analyzerRef: Any?
    private var transcriberRef: Any?

    private var resultsStream: AsyncStream<TranscriptionResult>!
    private var continuation: AsyncStream<TranscriptionResult>.Continuation!

    init() {
        let stream = AsyncStream<TranscriptionResult> { continuation in
            self.continuation = continuation
        }
        self.resultsStream = stream
    }

    var results: AsyncStream<TranscriptionResult> { resultsStream }

    func start(with input: AsyncStream<AudioChunk>) async throws {
        // NOTE: Minimal placeholder wiring. Real processing is expected to feed
        // bytes into SpeechAnalyzer and consume SpeechTranscriber outputs.
        // This placeholder forwards no results but validates integration points.
        _ = input // suppress unused in placeholder

        // Ensure types are linked without constraining initializer choices.
        // Referencing types keeps the binary linked with Speech modules.
        _ = SpeechAnalyzer.self
        _ = SpeechTranscriber.self
        analyzerRef = nil
        transcriberRef = nil
    }

    func stop() async {
        continuation?.finish()
        analyzerRef = nil
        transcriberRef = nil
    }
}

@available(iOS 26, *)
final class IOSAssetManager: AssetManaging {

    func ensureAssetsAvailable() async -> Bool {
        // Placeholder: assume available. Real implementation would check inventory.
        return true
    }

    func installIfNeeded() async throws -> Bool {
        // Placeholder: assume success. Real implementation would trigger install via AssetInventory APIs.
        return true
    }
}

@available(iOS 26, *)
extension IOSSpeechEngine: @unchecked Sendable {}
@available(iOS 26, *)
extension IOSAssetManager: @unchecked Sendable {}

#endif

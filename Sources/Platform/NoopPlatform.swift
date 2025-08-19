import Foundation

// Fallback engine and assets for non-iOS or when iOS 26 APIs are unavailable.
final class NoopEngine: TranscriptionEngine {
    private let stream: AsyncStream<TranscriptionResult>
    private var cont: AsyncStream<TranscriptionResult>.Continuation?

    init() {
        var c: AsyncStream<TranscriptionResult>.Continuation?
        self.stream = AsyncStream { continuation in c = continuation }
        self.cont = c
    }

    var results: AsyncStream<TranscriptionResult> { stream }
    func start(with input: AsyncStream<AudioChunk>) async throws { _ = input }
    func stop() async { cont?.finish() }
}

final class NoopAssets: AssetManaging {
    func ensureAssetsAvailable() async -> Bool { true }
    func installIfNeeded() async throws -> Bool { true }
}

extension NoopEngine: @unchecked Sendable {}
extension NoopAssets: @unchecked Sendable {}

// Default audio input fallback when microphone is unavailable.
final class NoopMicrophone: AudioInput {
    private let stream = AsyncStream<AudioChunk> { _ in }
    func start() async throws {}
    func stop() async {}
    var chunks: AsyncStream<AudioChunk> { stream }
}

extension NoopMicrophone: @unchecked Sendable {}

import Foundation

// Fallback engine for non-iOS or when iOS 26 APIs are unavailable.
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

extension NoopEngine: @unchecked Sendable {}

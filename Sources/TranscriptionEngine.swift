import Foundation

/// Abstract transcription engine built on platform frameworks.
protocol TranscriptionEngine: Sendable {
    func start(with input: AsyncStream<AudioChunk>) async throws
    var results: AsyncStream<TranscriptionResult> { get }
    func stop() async
}


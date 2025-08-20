import Foundation

// Default audio input fallback when microphone is unavailable.
final class NoopMicrophone: AudioInput {
    private let stream = AsyncStream<AudioChunk> { _ in }
    func start() async throws {}
    func stop() async {}
    var chunks: AsyncStream<AudioChunk> { stream }
}

extension NoopMicrophone: @unchecked Sendable {}


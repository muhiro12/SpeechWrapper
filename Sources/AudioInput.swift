import Foundation

/// Abstracts an audio input source (e.g., microphone, file reader).
protocol AudioInput: Sendable {
    /// Start producing audio chunks.
    func start() async throws
    /// Stop producing audio chunks and release resources.
    func stop() async
    /// Stream of audio data chunks.
    var chunks: AsyncStream<AudioChunk> { get }
}


import Foundation

/// Abstracts an audio input source (e.g., microphone, file reader).
@available(iOS 26, *)
public protocol AudioInput: Sendable {
    /// Start producing audio chunks.
    func start() async throws
    /// Stop producing audio chunks and release resources.
    func stop() async
    /// Stream of audio data chunks.
    var chunks: AsyncStream<AudioChunk> { get }
}

/// Abstract transcription engine built on platform frameworks.
protocol TranscriptionEngine: Sendable {
    func start(with input: AsyncStream<AudioChunk>) async throws
    var results: AsyncStream<TranscriptionResult> { get }
    func stop() async
}

/// Asset manager abstraction for on-device models.
protocol AssetManaging: Sendable {
    /// Returns true if required assets are already available.
    func ensureAssetsAvailable() async -> Bool
    /// Attempts to install missing assets. Returns true on success.
    func installIfNeeded() async throws -> Bool
}


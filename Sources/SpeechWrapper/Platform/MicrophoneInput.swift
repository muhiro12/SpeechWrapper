import Foundation

#if os(iOS)
@available(iOS 26, *)
final class MicrophoneInput: AudioInput {
    private var cont: AsyncStream<AudioChunk>.Continuation!
    private let streamImpl: AsyncStream<AudioChunk>

    init() {
        var c: AsyncStream<AudioChunk>.Continuation!
        self.streamImpl = AsyncStream { continuation in c = continuation }
        self.cont = c
    }

    var chunks: AsyncStream<AudioChunk> { streamImpl }
    func start() async throws {}
    func stop() async { cont.finish() }
}

@available(iOS 26, *)
extension MicrophoneInput: @unchecked Sendable {}

#endif

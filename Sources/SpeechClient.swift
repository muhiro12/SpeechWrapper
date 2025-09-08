import Foundation

/// Instance-based client: start a stream, stop when done.
public final actor SpeechClient {
    private let settings: SpeechClientSettings
    private var service: TranscriptionService?
    private var stopRequested = false

    public init(settings: SpeechClientSettings = .init()) {
        self.settings = settings
    }

    /// Streaming recognition: does not auto-finish on final; finish by stop() or consumer termination.
    public func stream() async throws -> AsyncStream<String> {
        let transcriptionService = TranscriptionService.usingMicrophone(locale: settings.locale,
                                                                         forceLegacy: settings.useLegacy)
        self.service = transcriptionService
        let source = try await transcriptionService.startStreaming()
        return AsyncStream<String> { continuation in
            let task = Task {
                for await result in source {
                    if self.stopRequested {
                        continuation.finish()
                        break
                    }
                    continuation.yield(result.text)
                }
            }
            continuation.onTermination = { _ in
                task.cancel()
                Task { await transcriptionService.stop() }
            }
        }
    }

    /// Stop the active stream and release resources.
    public func stop() { stopRequested = true }
}

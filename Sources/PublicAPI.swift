import Foundation

public struct SpeechClientSettings: Sendable, Equatable {
    public var locale: Locale?
    public var useLegacy: Bool

    public init(locale: Locale? = nil,
                useLegacy: Bool = false) {
        self.locale = locale
        self.useLegacy = useLegacy
    }
}

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
        let svc = TranscriptionService.usingMicrophone(locale: settings.locale,
                                                       forceLegacy: settings.useLegacy)
        self.service = svc
        let source = try await svc.startStreaming()
        return AsyncStream<String> { continuation in
            let task = Task {
                for await r in source {
                    if self.stopRequested {
                        continuation.finish()
                        break
                    }
                    continuation.yield(r.text)
                }
            }
            continuation.onTermination = { _ in
                task.cancel()
                Task { await svc.stop() }
            }
        }
    }

    /// Stop the active stream and release resources.
    public func stop() { stopRequested = true }
}

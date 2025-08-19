import Foundation

public enum CancelPolicy: Sendable { case throwError, returnEmpty }

public struct SpeechClientSettings: Sendable, Equatable {
    public var useLegacy: Bool
    public var cancelPolicy: CancelPolicy

    public init(useLegacy: Bool = false, cancelPolicy: CancelPolicy = .throwError) {
        self.useLegacy = useLegacy
        self.cancelPolicy = cancelPolicy
    }
}

/// Instance-based client with simple control methods (`stop()`, `cancel()`).
public final actor SpeechClient {
    private let settings: SpeechClientSettings
    private var service: TranscriptionService?
    private var stopRequested = false
    private var cancelRequested = false

    public init(settings: SpeechClientSettings = .init()) {
        self.settings = settings
    }

    /// One-shot recognition.
    public func transcribe() async throws -> String {
        let svc = TranscriptionService.usingMicrophone(forceLegacy: settings.useLegacy)
        self.service = svc
        defer { Task { await svc.stop() } }

        let stream = try await svc.startStreaming()
        var latestText = ""
        for await r in stream {
            latestText = r.text
            if r.isFinal { return latestText }
            if cancelRequested { return try await handleCancel() }
            if stopRequested { return latestText }
        }
        throw TranscriptionError.transcriberFailed
    }

    /// Streaming recognition.
    public func stream() async throws -> AsyncStream<String> {
        let svc = TranscriptionService.usingMicrophone(forceLegacy: settings.useLegacy)
        self.service = svc
        let source = try await svc.startStreaming()
        return AsyncStream<String> { continuation in
            let task = Task {
                for await r in source {
                    if self.cancelRequested {
                        _ = try? await self.handleCancel()
                        continuation.finish()
                        break
                    }
                    if self.stopRequested {
                        continuation.finish()
                        break
                    }
                    continuation.yield(r.text)
                    if r.isFinal {
                        await svc.stop()
                        continuation.finish()
                        break
                    }
                }
            }
            continuation.onTermination = { _ in
                task.cancel()
                Task { await svc.stop() }
            }
        }
    }

    public func stop() { stopRequested = true }
    public func cancel() { cancelRequested = true }

    private func handleCancel() async throws -> String {
        switch settings.cancelPolicy {
        case .returnEmpty: return ""
        case .throwError: throw TranscriptionError.cancelled
        }
    }
}

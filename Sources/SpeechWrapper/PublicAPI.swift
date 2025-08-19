import Foundation

public enum CancelPolicy: Sendable { case throwError, returnEmpty }

public struct SpeechClientSettings: Sendable, Equatable {
    public var useLegacy: Bool
    public var cancelPolicy: CancelPolicy

    public init(cancelPolicy: CancelPolicy = .throwError, useLegacy: Bool = false) {
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

    /// Begin a controllable transcription session and return a handle.
    /// Call `wait()` to get the final/stop/cancel result later.
    public func beginTranscribe() async throws -> SpeechTranscription {
        let svc = TranscriptionService.usingMicrophone(forceLegacy: settings.useLegacy)
        let source = try await svc.startStreaming()
        let session = SpeechTranscription(service: svc, settings: settings)
        await session.start(with: source)
        return session
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

/// A single transcription session handle.
public final actor SpeechTranscription {
    private let settings: SpeechClientSettings
    private let service: TranscriptionService
    private var stream: AsyncStream<TranscriptionResult>?
    private var latestText: String = ""
    private var finishedText: String?
    private var finishedError: Error?
    private var waiter: CheckedContinuation<String, Error>?
    private var readerTask: Task<Void, Never>?
    private var stopRequested = false
    private var cancelRequested = false

    init(service: TranscriptionService, settings: SpeechClientSettings) {
        self.service = service
        self.settings = settings
    }

    func start(with stream: AsyncStream<TranscriptionResult>) {
        self.stream = stream
        readerTask = Task { [weak self] in
            await self?.run(stream: stream)
        }
    }

    private func run(stream: AsyncStream<TranscriptionResult>) async {
        for await r in stream {
            latestText = r.text
            if r.isFinal {
                await finish(with: r.text)
                return
            }
            if cancelRequested {
                await finishByCancel()
                return
            }
            if stopRequested {
                await finish(with: latestText)
                return
            }
        }
        if finishedText == nil && finishedError == nil {
            await finish(error: TranscriptionError.transcriberFailed)
        }
    }

    public func wait() async throws -> String {
        if let t = finishedText { return t }
        if let e = finishedError { throw e }
        return try await withCheckedThrowingContinuation { (cont: CheckedContinuation<String, Error>) in
            self.waiter = cont
        }
    }

    public func stop() { stopRequested = true }
    public func cancel() { cancelRequested = true }

    private func finish(with text: String) async {
        finishedText = text
        await cleanup()
        if let waiter = waiter { waiter.resume(returning: text); self.waiter = nil }
    }

    private func finish(error: Error) async {
        finishedError = error
        await cleanup()
        if let waiter = waiter { waiter.resume(throwing: error); self.waiter = nil }
    }

    private func finishByCancel() async {
        switch settings.cancelPolicy {
        case .returnEmpty:
            await finish(with: "")
        case .throwError:
            await finish(error: TranscriptionError.cancelled)
        }
    }

    private func cleanup() async {
        await service.stop()
        readerTask?.cancel()
        readerTask = nil
        stream = nil
    }
}

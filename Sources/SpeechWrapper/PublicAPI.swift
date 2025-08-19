import Foundation

/// Public entry point type avoiding collision with Apple's `Speech` framework.
public enum SpeechClient {

    // Control surface to allow manual stop/cancel while a transcribe() call is awaiting.
    public actor Control {
        private var stopRequested = false
        private var cancelRequested = false

        public init() {}
        public func stop() { stopRequested = true }
        public func cancel() { cancelRequested = true }
        func snapshot() -> (stop: Bool, cancel: Bool) { (stopRequested, cancelRequested) }
    }

    public enum CancelPolicy { case throwError, returnEmpty }
    /// One-shot: starts mic and returns the final transcript text.
    public static func transcribe(useLegacy: Bool = false,
                                  control: Control? = nil,
                                  cancelPolicy: CancelPolicy = .throwError) async throws -> String {
        let service = TranscriptionService.usingMicrophone(forceLegacy: useLegacy)
        let source = try await service.startStreaming()
        defer { Task { await service.stop() } }

        var latestText = ""
        for await r in source {
            latestText = r.text
            if r.isFinal { return latestText }

            if let control = control {
                let flags = await control.snapshot()
                if flags.cancel {
                    if cancelPolicy == .returnEmpty { return "" }
                    throw TranscriptionError.cancelled
                }
                if flags.stop {
                    return latestText
                }
            }
        }
        // Stream ended without a final result and without explicit stop/cancel.
        throw TranscriptionError.transcriberFailed
    }

    /// Streaming: yields partial/final texts; auto-finishes on final or cancellation.
    public static func stream(useLegacy: Bool = false) async throws -> AsyncStream<String> {
        let service = TranscriptionService.usingMicrophone(forceLegacy: useLegacy)
        let source = try await service.startStreaming()
        return AsyncStream<String> { continuation in
            let task = Task {
                for await r in source {
                    continuation.yield(r.text)
                    if r.isFinal {
                        await service.stop()
                        continuation.finish()
                        break
                    }
                }
            }
            continuation.onTermination = { _ in
                task.cancel()
                Task { await service.stop() }
            }
        }
    }
}

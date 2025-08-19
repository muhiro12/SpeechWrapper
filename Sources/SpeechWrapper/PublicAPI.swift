import Foundation

/// Public entry point type avoiding collision with Apple's `Speech` framework.
public enum SpeechClient {
    /// One-shot: starts mic and returns the final transcript text.
    public static func transcribe() async throws -> String {
        let service = TranscriptionService.usingMicrophone()
        let final = try await service.transcribeOnce()
        return final.text
    }

    /// Streaming: yields partial/final texts; auto-finishes on final or cancellation.
    public static func stream() async throws -> AsyncStream<String> {
        let service = TranscriptionService.usingMicrophone()
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

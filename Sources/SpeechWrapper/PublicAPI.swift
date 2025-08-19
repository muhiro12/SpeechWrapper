import Foundation

/// Very small public surface: two functions only.
/// - Note: These APIs use the built-in microphone and return plain `String`s.
@available(iOS 26, *)
public func speechToText() async throws -> String {
    let service = TranscriptionService.usingMicrophone()
    let final = try await service.transcribeOnce()
    // `transcribeOnce` internally stops the service.
    return final.text
}

/// Starts microphone speech recognition and returns a stream of partial/final texts.
/// - Behavior: Yields interim strings while listening. Automatically stops when a final result arrives
///   or when the consumer cancels/finishes the stream iteration.
@available(iOS 26, *)
public func speechToTextStream() async throws -> AsyncStream<String> {
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

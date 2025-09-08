import XCTest
@testable import SpeechWrapper

final class XCTestAdapterTests: XCTestCase {

    // MARK: - Test Doubles (simplified)
    final class MockAudioInput: AudioInput {
        private let stream: AsyncStream<AudioChunk>
        private let continuation: AsyncStream<AudioChunk>.Continuation
        init() {
            var tempContinuation: AsyncStream<AudioChunk>.Continuation!
            self.stream = AsyncStream { continuation in
                tempContinuation = continuation
            }
            self.continuation = tempContinuation
        }
        var chunks: AsyncStream<AudioChunk> { stream }
        func start() async throws {}
        func stop() async { continuation.finish() }
        func send(_ chunk: AudioChunk) { continuation.yield(chunk) }
    }

    final class MockEngine: TranscriptionEngine {
        private let stream: AsyncStream<TranscriptionResult>
        private let continuation: AsyncStream<TranscriptionResult>.Continuation
        init() {
            var tempContinuation: AsyncStream<TranscriptionResult>.Continuation!
            self.stream = AsyncStream { continuation in
                tempContinuation = continuation
            }
            self.continuation = tempContinuation
        }
        var results: AsyncStream<TranscriptionResult> { stream }
        func start(with input: AsyncStream<AudioChunk>) async throws {
            Task {
                for await _ in input {
                }
            }
        }
        func stop() async { continuation.finish() }
        func emit(_ result: TranscriptionResult) { continuation.yield(result) }
    }

    final class MockAssets: AssetManaging {
        func ensureAssetsAvailable() async -> Bool { true }
        func installIfNeeded() async throws -> Bool { true }
    }

    func test_transcribeOnce_returnsFinal() async throws {
        let input = MockAudioInput()
        let engine = MockEngine()
        let assets = MockAssets()
        let service = TranscriptionService(audioInput: input, engine: engine, assets: assets)

        let task = Task { try await service.transcribeOnce() }
        await Task.yield()
        engine.emit(.init(text: "hello", isFinal: false))
        engine.emit(.init(text: "hello world", isFinal: true))

        let final = try await task.value
        XCTAssertEqual(final, .init(text: "hello world", isFinal: true))
        await service.stop()
    }

    func test_streaming_yields_and_stop() async throws {
        let input = MockAudioInput()
        let engine = MockEngine()
        let assets = MockAssets()
        let service = TranscriptionService(audioInput: input, engine: engine, assets: assets)

        let stream = try await service.startStreaming()

        let collector = Task<[TranscriptionResult], Never> {
            var resultsArray: [TranscriptionResult] = []
            for await result in stream {
                resultsArray.append(result)
                if result.isFinal {
                    break
                }
            }
            return resultsArray
        }

        engine.emit(.init(text: "hi", isFinal: false))
        engine.emit(.init(text: "hi there", isFinal: true))

        let results = await collector.value
        XCTAssertEqual(results, [.init(text: "hi", isFinal: false), .init(text: "hi there", isFinal: true)])
        await service.stop()
    }

    func test_error_has_message() throws {
        let err: Error = TranscriptionError.notAuthorized
        XCTAssertFalse(err.localizedDescription.isEmpty)
    }
}

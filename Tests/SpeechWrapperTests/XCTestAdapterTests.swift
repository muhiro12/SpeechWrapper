import XCTest
@testable import SpeechWrapper

@available(iOS 26, *)
final class XCTestAdapterTests: XCTestCase {

    // MARK: - Test Doubles (simplified)
    final class MockAudioInput: AudioInput {
        private let streamImpl: AsyncStream<AudioChunk>
        private let cont: AsyncStream<AudioChunk>.Continuation
        init() {
            var c: AsyncStream<AudioChunk>.Continuation!
            self.streamImpl = AsyncStream { cont in c = cont }
            self.cont = c
        }
        var chunks: AsyncStream<AudioChunk> { streamImpl }
        func start() async throws {}
        func stop() async { cont.finish() }
        func send(_ chunk: AudioChunk) { cont.yield(chunk) }
    }

    final class MockEngine: TranscriptionEngine {
        private let streamImpl: AsyncStream<TranscriptionResult>
        private let cont: AsyncStream<TranscriptionResult>.Continuation
        init() {
            var c: AsyncStream<TranscriptionResult>.Continuation!
            self.streamImpl = AsyncStream { cont in c = cont }
            self.cont = c
        }
        var results: AsyncStream<TranscriptionResult> { streamImpl }
        func start(with input: AsyncStream<AudioChunk>) async throws {
            Task { for await _ in input { } }
        }
        func stop() async { cont.finish() }
        func emit(_ r: TranscriptionResult) { cont.yield(r) }
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
            var arr: [TranscriptionResult] = []
            for await r in stream { arr.append(r); if r.isFinal { break } }
            return arr
        }

        engine.emit(.init(text: "hi", isFinal: false))
        engine.emit(.init(text: "hi there", isFinal: true))

        let results = await collector.value
        XCTAssertEqual(results, [.init(text: "hi", isFinal: false), .init(text: "hi there", isFinal: true)])
        await service.stop()
    }
}


import XCTest
@testable import SpeechWrapper

// MARK: - Test Doubles

@available(iOS 26, *)
final class MockAudioInput: AudioInput {
    private let subject: AsyncStream<AudioChunk>
    private let continuation: AsyncStream<AudioChunk>.Continuation
    private(set) var started = false
    private(set) var stopped = false

    init() {
        var c: AsyncStream<AudioChunk>.Continuation!
        self.subject = AsyncStream<AudioChunk> { continuation in
            continuation.onTermination = { _ in }
            c = continuation
        }
        self.continuation = c
    }

    var chunks: AsyncStream<AudioChunk> { subject }

    func start() async throws { started = true }
    func stop() async { stopped = true; continuation.finish() }

    func send(_ chunk: AudioChunk) { continuation.yield(chunk) }
    func finish() { continuation.finish() }
}

@available(iOS 26, *)
final class MockEngine: TranscriptionEngine {
    private let stream: AsyncStream<TranscriptionResult>
    private let continuation: AsyncStream<TranscriptionResult>.Continuation
    private(set) var started = false
    private(set) var stopped = false

    init() {
        var c: AsyncStream<TranscriptionResult>.Continuation!
        self.stream = AsyncStream { continuation in c = continuation }
        self.continuation = c
    }

    var results: AsyncStream<TranscriptionResult> { stream }

    func start(with input: AsyncStream<AudioChunk>) async throws {
        started = true
        // Drive results asynchronously to simulate interim and final outputs
        Task {
            for await _ in input { /* ignore */ }
        }
    }

    func stop() async { stopped = true; continuation.finish() }

    func emit(_ result: TranscriptionResult) { continuation.yield(result) }
    func finish() { continuation.finish() }
}

@available(iOS 26, *)
final class MockAssetsManager: AssetManaging {
    var available: Bool
    var installSucceeds: Bool
    private(set) var ensureCount = 0
    private(set) var installCount = 0

    init(available: Bool, installSucceeds: Bool) {
        self.available = available
        self.installSucceeds = installSucceeds
    }

    func ensureAssetsAvailable() async -> Bool { ensureCount += 1; return available }
    func installIfNeeded() async throws -> Bool { installCount += 1; if installSucceeds { available = true }; return installSucceeds }
}

@available(iOS 26, *)
extension MockAudioInput: @unchecked Sendable {}
@available(iOS 26, *)
extension MockEngine: @unchecked Sendable {}
@available(iOS 26, *)
extension MockAssetsManager: @unchecked Sendable {}

// MARK: - Tests

@available(iOS 26, *)
final class TranscriptionServiceTests: XCTestCase {
    func testSequenceInterimFinalStop() async throws {
        let input = MockAudioInput()
        let engine = MockEngine()
        let assets = MockAssetsManager(available: true, installSucceeds: true)
        let service = TranscriptionService(audioInput: input, engine: engine, assets: assets)

        let stream = await service.resultStream()
        let collector = Task { () -> [TranscriptionResult] in
            var arr: [TranscriptionResult] = []
            for await r in stream { arr.append(r) }
            return arr
        }

        try await service.start()
        XCTAssertTrue(engine.started)
        XCTAssertTrue(input.started)

        engine.emit(.init(text: "hello", isFinal: false))
        engine.emit(.init(text: "hello world", isFinal: true))

        await service.stop()
        let results = await collector.value

        XCTAssertTrue(engine.stopped)
        XCTAssertTrue(input.stopped)
        XCTAssertEqual(results.count, 2)
        XCTAssertEqual(results[0], .init(text: "hello", isFinal: false))
        XCTAssertEqual(results[1], .init(text: "hello world", isFinal: true))
    }

    func testAssetsInstallRetrySuccess() async throws {
        let input = MockAudioInput()
        let engine = MockEngine()
        let assets = MockAssetsManager(available: false, installSucceeds: true)
        let service = TranscriptionService(audioInput: input, engine: engine, assets: assets)

        // First attempt: not available, but prepare will install
        let prepared = await service.prepareAssetsIfNeeded()
        XCTAssertTrue(prepared)
        XCTAssertEqual(assets.installCount, 1)

        // Now start should succeed
        try await service.start()
        await service.stop()
    }

    func testStopReleasesResources() async throws {
        let input = MockAudioInput()
        let engine = MockEngine()
        let assets = MockAssetsManager(available: true, installSucceeds: true)
        let service = TranscriptionService(audioInput: input, engine: engine, assets: assets)

        try await service.start()
        await service.stop()

        // stopping again should be a no-op and not crash
        await service.stop()

        XCTAssertTrue(engine.stopped)
        XCTAssertTrue(input.stopped)
    }
}

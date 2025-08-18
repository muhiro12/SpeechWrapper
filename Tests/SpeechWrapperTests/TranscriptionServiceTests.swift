import Testing
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
        Task { for await _ in input { /* ignore */ } }
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

// MARK: - Tests (Swift Testing)

@available(iOS 26, *)
@Test func streaming_twoResults_then_stop() async throws {
    let input = MockAudioInput()
    let engine = MockEngine()
    let assets = MockAssetsManager(available: true, installSucceeds: true)
    let service = TranscriptionService(audioInput: input, engine: engine, assets: assets)

    let stream = try await service.startStreaming()
    #expect(engine.started)
    #expect(input.started)

    let collector = Task { () -> [TranscriptionResult] in
        var arr: [TranscriptionResult] = []
        for await r in stream {
            arr.append(r)
            if arr.count == 2 { break }
        }
        return arr
    }

    engine.emit(.init(text: "hello", isFinal: false))
    engine.emit(.init(text: "hello world", isFinal: true))

    let results = await collector.value
    await service.stop()

    #expect(engine.stopped)
    #expect(input.stopped)
    #expect(results.count == 2)
    #expect(results[0] == .init(text: "hello", isFinal: false))
    #expect(results[1] == .init(text: "hello world", isFinal: true))
}

@available(iOS 26, *)
@Test func assets_install_then_start_succeeds() async throws {
    let input = MockAudioInput()
    let engine = MockEngine()
    let assets = MockAssetsManager(available: false, installSucceeds: true)
    let service = TranscriptionService(audioInput: input, engine: engine, assets: assets)

    _ = try await service.startStreaming()
    await service.stop()

    #expect(assets.installCount == 1)
}

@available(iOS 26, *)
@Test func stop_is_idempotent() async throws {
    let input = MockAudioInput()
    let engine = MockEngine()
    let assets = MockAssetsManager(available: true, installSucceeds: true)
    let service = TranscriptionService(audioInput: input, engine: engine, assets: assets)

    _ = try await service.startStreaming()
    await service.stop()
    await service.stop()

    #expect(engine.stopped)
    #expect(input.stopped)
}

@available(iOS 26, *)
@Test func transcribeOnce_returns_final() async throws {
    let input = MockAudioInput()
    let engine = MockEngine()
    let assets = MockAssetsManager(available: true, installSucceeds: true)
    let service = TranscriptionService(audioInput: input, engine: engine, assets: assets)

    let t = Task { try await service.transcribeOnce() }
    await Task.yield()
    engine.emit(.init(text: "hello", isFinal: false))
    engine.emit(.init(text: "hello world", isFinal: true))

    let final = try await t.value
    #expect(final == .init(text: "hello world", isFinal: true))
    await service.stop()
    #expect(engine.stopped)
    #expect(input.stopped)
}

@available(iOS 26, *)
@Test func start_while_running_throws() async {
    let input = MockAudioInput()
    let engine = MockEngine()
    let assets = MockAssetsManager(available: true, installSucceeds: true)
    let service = TranscriptionService(audioInput: input, engine: engine, assets: assets)

    _ = try? await service.startStreaming()
    var thrown: Error?
    do {
        _ = try await service.startStreaming()
    } catch {
        thrown = error
    }
    #expect(thrown is TranscriptionError)
    await service.stop()
}

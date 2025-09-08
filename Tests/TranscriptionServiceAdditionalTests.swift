import Testing
@testable import SpeechWrapper

// MARK: - Additional Test Doubles

final class ThrowingAudioInput: AudioInput {
    enum Behavior { case ok, throwsOnStart }
    private let behavior: Behavior
    private let stream: AsyncStream<AudioChunk>
    private let continuation: AsyncStream<AudioChunk>.Continuation
    private(set) var started = false
    private(set) var stopped = false

    init(_ behavior: Behavior) {
        self.behavior = behavior
        var tempContinuation: AsyncStream<AudioChunk>.Continuation!
        self.stream = AsyncStream { continuation in
            tempContinuation = continuation
        }
        self.continuation = tempContinuation
    }

    var chunks: AsyncStream<AudioChunk> { stream }
    func start() async throws {
        started = true
        if behavior == .throwsOnStart {
            throw TranscriptionError.audioUnavailable
        }
    }
    func stop() async {
        stopped = true
        continuation.finish()
    }
}

final class ThrowingEngine: TranscriptionEngine {
    enum Behavior { case ok, throwsOnStart }
    private let behavior: Behavior
    private let stream: AsyncStream<TranscriptionResult>
    private let continuation: AsyncStream<TranscriptionResult>.Continuation
    private(set) var started = false
    private(set) var stopped = false

    init(_ behavior: Behavior) {
        self.behavior = behavior
        var tempContinuation: AsyncStream<TranscriptionResult>.Continuation!
        self.stream = AsyncStream { continuation in
            tempContinuation = continuation
        }
        self.continuation = tempContinuation
    }

    var results: AsyncStream<TranscriptionResult> { stream }
    func start(with input: AsyncStream<AudioChunk>) async throws {
        started = true
        if behavior == .throwsOnStart {
            throw TranscriptionError.setupFailed
        }
        // keep input alive until stopped
        Task {
            for await _ in input {
            }
        }
    }
    func stop() async {
        stopped = true
        continuation.finish()
    }
    func emit(_ result: TranscriptionResult) { continuation.yield(result) }
}

final class ToggleAssets: AssetManaging {
    var available: Bool
    var installSucceeds: Bool
    init(available: Bool, installSucceeds: Bool) {
        self.available = available
        self.installSucceeds = installSucceeds
    }
    func ensureAssetsAvailable() async -> Bool { available }
    func installIfNeeded() async throws -> Bool {
        if installSucceeds {
            available = true
        }
        return installSucceeds
    }
}

extension ThrowingAudioInput: @unchecked Sendable {}
extension ThrowingEngine: @unchecked Sendable {}
extension ToggleAssets: @unchecked Sendable {}

// MARK: - Tests (Swift Testing)

@Test func start_fails_when_assets_install_fails() async {
    let input = ThrowingAudioInput(.ok)
    let engine = ThrowingEngine(.ok)
    let assets = ToggleAssets(available: false, installSucceeds: false)
    let service = TranscriptionService(audioInput: input, engine: engine, assets: assets)

    var thrown: Error?
    do {
        _ = try await service.startStreaming()
    } catch {
        thrown = error
    }
    #expect((thrown as? TranscriptionError) == .modelUnavailable)
}

@Test func start_fails_when_audio_unavailable() async {
    let input = ThrowingAudioInput(.throwsOnStart)
    let engine = ThrowingEngine(.ok)
    let assets = ToggleAssets(available: true, installSucceeds: true)
    let service = TranscriptionService(audioInput: input, engine: engine, assets: assets)

    await #expect(throws: TranscriptionError.audioUnavailable) {
        _ = try await service.startStreaming()
    }
}

@Test func start_fails_when_engine_setup_fails() async {
    let input = ThrowingAudioInput(.ok)
    let engine = ThrowingEngine(.throwsOnStart)
    let assets = ToggleAssets(available: true, installSucceeds: true)
    // Disable legacy fallback to observe the original setup failure
    let service = TranscriptionService(audioInput: input,
                                       engine: engine,
                                       assets: assets,
                                       locale: .current,
                                       forceLegacyRequested: true)

    await #expect(throws: TranscriptionError.setupFailed) {
        _ = try await service.startStreaming()
    }
}

@Test func broadcast_to_multiple_subscribers_and_finish_on_stop() async throws {
    let input = ThrowingAudioInput(.ok)
    let engine = ThrowingEngine(.ok)
    let assets = ToggleAssets(available: true, installSucceeds: true)
    let service = TranscriptionService(audioInput: input, engine: engine, assets: assets)

    // Subscribe before start
    let stream1 = await service.resultStream()
    let stream2 = await service.resultStream()
    try await service.start()

    let collector1 = Task { () -> [TranscriptionResult] in
        var resultsArray: [TranscriptionResult] = []
        for await result in stream1 {
            resultsArray.append(result)
        }
        return resultsArray
    }
    let collector2 = Task { () -> [TranscriptionResult] in
        var resultsArray: [TranscriptionResult] = []
        for await result in stream2 {
            resultsArray.append(result)
        }
        return resultsArray
    }

    engine.emit(.init(text: "one", isFinal: false))
    engine.emit(.init(text: "two", isFinal: true))
    await service.stop()

    let results1 = await collector1.value
    let results2 = await collector2.value
    #expect(results1 == [.init(text: "one", isFinal: false), .init(text: "two", isFinal: true)])
    #expect(results1 == results2)
}

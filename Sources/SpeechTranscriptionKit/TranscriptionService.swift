import Foundation

/// Actor-based facade providing a thin, clean API for speech-to-text.
/// - Availability: iOS 26+
@available(iOS 26, *)
public actor TranscriptionService {
    private let audioInput: any AudioInput
    private let engine: any TranscriptionEngine
    private let assets: any AssetManaging

    private var isRunning = false
    private var forwarderTask: Task<Void, Never>? = nil

    // Multicast to subscribers
    private var subscribers: [UUID: AsyncStream<TranscriptionResult>.Continuation] = [:]

    /// Public initializer usingプラットフォーム既定のエンジン/アセット。
    public init(audioInput: any AudioInput) {
        self.audioInput = audioInput
        self.engine = PlatformDefaults.makeEngine()
        self.assets = PlatformDefaults.makeAssets()
    }

    /// Internal initializer for DI（ユニットテスト用）。
    init(audioInput: any AudioInput, engine: any TranscriptionEngine, assets: any AssetManaging) {
        self.audioInput = audioInput
        self.engine = engine
        self.assets = assets
    }

    /// Returns a stream of transcription results. Subscribe before or after `start()`.
    public func resultStream() -> AsyncStream<TranscriptionResult> {
        let id = UUID()
        return AsyncStream { continuation in
            subscribers[id] = continuation
            continuation.onTermination = { [weak self] _ in
                Task { await self?.removeSubscriber(id) }
            }
        }
    }

    private func removeSubscriber(_ id: UUID) {
        subscribers.removeValue(forKey: id)
    }

    /// Ensures necessary on-device assets are available, attempting installation if missing.
    /// - Returns: true if assets are available after this call.
    @discardableResult
    public func prepareAssetsIfNeeded() async -> Bool {
        if await assets.ensureAssetsAvailable() { return true }
        do {
            let ok = try await assets.installIfNeeded()
            if !ok { return false }
            return await assets.ensureAssetsAvailable()
        } catch {
            return false
        }
    }

    /// Start transcription pipeline.
    public func start() async throws {
        if isRunning { throw TranscriptionError.alreadyRunning }
        guard await prepareAssetsIfNeeded() else { throw TranscriptionError.modelUnavailable }

        do {
            try await audioInput.start()
        } catch {
            throw TranscriptionError.audioUnavailable
        }

        do {
            try await engine.start(with: audioInput.chunks)
        } catch {
            throw TranscriptionError.setupFailed
        }

        isRunning = true
        let resultsStream = engine.results
        forwarderTask = Task { [weak self] in
            guard let self else { return }
            for await result in resultsStream {
                await self.broadcast(result)
            }
        }
    }

    /// Stop transcription pipeline and release resources.
    public func stop() async {
        guard isRunning else { return }
        isRunning = false
        forwarderTask?.cancel()
        forwarderTask = nil
        await engine.stop()
        await audioInput.stop()
        finishAll()
    }

    private func broadcast(_ result: TranscriptionResult) {
        for continuation in subscribers.values {
            continuation.yield(result)
        }
    }

    private func finishAll() {
        for (_, c) in subscribers { c.finish() }
        subscribers.removeAll(keepingCapacity: false)
    }
}

enum PlatformDefaults {
    static func makeEngine() -> any TranscriptionEngine {
        #if os(iOS) && canImport(Speech)
        if #available(iOS 26, *) {
            return IOSSpeechEngine()
        }
        #endif
        return NoopEngine()
    }

    static func makeAssets() -> any AssetManaging {
        #if os(iOS) && canImport(Speech)
        if #available(iOS 26, *) {
            return IOSAssetManager()
        }
        #endif
        return NoopAssets()
    }
}

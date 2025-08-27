import Foundation

/// Actor-based facade providing a thin, clean API for speech-to-text.
actor TranscriptionService {
    private let audioInput: any AudioInput
    private var engine: any TranscriptionEngine
    private var assets: any AssetManaging
    private let locale: Locale
    private let forceLegacyRequested: Bool
    private var didFallbackToLegacy = false

    private var isRunning = false
    private var forwarderTask: Task<Void, Never>?

    // Multicast to subscribers
    private var subscribers: [UUID: AsyncStream<TranscriptionResult>.Continuation] = [:]

    /// Initializer using プラットフォーム既定のエンジン/アセット。
    init(audioInput: any AudioInput) {
        self.audioInput = audioInput
        self.locale = .current
        self.forceLegacyRequested = false
        self.engine = PlatformDefaults.makeEngine(locale: locale, forceLegacy: forceLegacyRequested)
        self.assets = PlatformDefaults.makeAssets(locale: locale, forceLegacy: forceLegacyRequested)
    }

    /// Factory: Service configured with built-in microphone input on iOS 26+.
    /// - Note: Falls back to a no-op input outside supported platforms.
    static func usingMicrophone(locale: Locale? = nil, forceLegacy: Bool = false) -> TranscriptionService {
        let input = PlatformDefaults.makeDefaultAudioInput()
        let effectiveLocale = locale ?? .current
        let engine = PlatformDefaults.makeEngine(locale: effectiveLocale, forceLegacy: forceLegacy)
        let assets = PlatformDefaults.makeAssets(locale: effectiveLocale, forceLegacy: forceLegacy)
        return TranscriptionService(audioInput: input,
                                    engine: engine,
                                    assets: assets,
                                    locale: effectiveLocale,
                                    forceLegacyRequested: forceLegacy)
    }

    /// Internal initializer for DI（ユニットテスト用）。
    init(audioInput: any AudioInput, engine: any TranscriptionEngine, assets: any AssetManaging) {
        self.audioInput = audioInput
        self.engine = engine
        self.assets = assets
        self.locale = .current
        self.forceLegacyRequested = false
    }

    /// Internal initializer used by factory to carry locale/flags.
    init(audioInput: any AudioInput,
         engine: any TranscriptionEngine,
         assets: any AssetManaging,
         locale: Locale,
         forceLegacyRequested: Bool) {
        self.audioInput = audioInput
        self.engine = engine
        self.assets = assets
        self.locale = locale
        self.forceLegacyRequested = forceLegacyRequested
    }

    /// Returns a stream of transcription results. Subscribe before or after `start()`.
    func resultStream() -> AsyncStream<TranscriptionResult> {
        let id = UUID()
        return AsyncStream { continuation in
            subscribers[id] = continuation
            continuation.onTermination = { [weak self] _ in
                Task { await self?.removeSubscriber(id) }
            }
        }
    }

    /// Convenience: Start streaming and return the results stream.
    /// Call `stop()` when you no longer need results.
    func startStreaming() async throws -> AsyncStream<TranscriptionResult> {
        let stream = resultStream()
        try await start()
        return stream
    }

    /// One-shot transcription: Starts, waits for the first final result, then stops.
    /// - Returns: The first final `TranscriptionResult` observed.
    func transcribeOnce() async throws -> TranscriptionResult {
        if isRunning { throw TranscriptionError.alreadyRunning }
        let stream = resultStream()
        try await start()
        defer { Task { await self.stop() } }

        for await r in stream {
            if r.isFinal { return r }
        }
        throw TranscriptionError.transcriberFailed
    }

    private func removeSubscriber(_ id: UUID) {
        subscribers.removeValue(forKey: id)
    }

    /// Ensures necessary on-device assets are available, attempting installation if missing.
    /// - Returns: true if assets are available after this call.
    @discardableResult
    func prepareAssetsIfNeeded() async -> Bool {
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
    func start() async throws {
        if isRunning { throw TranscriptionError.alreadyRunning }
        // Attempt primary engine; if it fails early on iOS 26+ and not forced legacy, try legacy once.
        do {
            try await startPipelineOnce()
        } catch {
            if await shouldAttemptLegacyFallback(after: error) {
                await performLegacyFallback()
                do {
                    try await startPipelineOnce()
                } catch {
                    throw error
                }
            } else {
                throw error
            }
        }
    }

    private func startPipelineOnce() async throws {
        guard await prepareAssetsIfNeeded() else { throw TranscriptionError.modelUnavailable }
        do { try await audioInput.start() } catch { throw TranscriptionError.audioUnavailable }
        do { try await engine.start(with: audioInput.chunks) } catch { throw TranscriptionError.setupFailed }

        isRunning = true
        let resultsStream = engine.results
        forwarderTask = Task { [weak self] in
            guard let self else { return }
            for await result in resultsStream { await self.broadcast(result) }
        }
    }

    private func shouldAttemptLegacyFallback(after error: Error) async -> Bool {
        if didFallbackToLegacy { return false }
        if forceLegacyRequested { return false }
        #if os(iOS)
        if #available(iOS 26, *) {
            // New engine path was selected; allow fallback for setup/asset failures.
            return (error as? TranscriptionError) == .modelUnavailable ||
                (error as? TranscriptionError) == .setupFailed
        } else {
            return false
        }
        #else
        return false
        #endif
    }

    private func performLegacyFallback() async {
        didFallbackToLegacy = true
        // Stop any partial pipeline.
        await engine.stop()
        await audioInput.stop()
        // Swap to legacy components and retry.
        self.engine = PlatformDefaults.makeEngine(locale: locale, forceLegacy: true)
        self.assets = PlatformDefaults.makeAssets(locale: locale, forceLegacy: true)
    }

    /// Stop transcription pipeline and release resources.
    func stop() async {
        guard isRunning else { return }
        isRunning = false
        // First, stop engine to naturally end the results stream.
        await engine.stop()
        await audioInput.stop()
        // Give the forwarder a chance to drain any final items.
        await Task.yield()
        forwarderTask?.cancel()
        forwarderTask = nil
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

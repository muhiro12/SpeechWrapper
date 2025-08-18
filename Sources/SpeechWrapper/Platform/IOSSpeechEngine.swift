import Foundation

#if os(iOS) && canImport(Speech)
import Speech
import AVFoundation

@available(iOS 26, *)
final class IOSSpeechEngine: TranscriptionEngine {
    private var analyzer: SpeechAnalyzer?
    private var transcriber: SpeechTranscriber?
    private var inputSequence: AsyncStream<AnalyzerInput>?
    private var inputBuilder: AsyncStream<AnalyzerInput>.Continuation?
    private var tasks: [Task<Void, Never>] = []

    private let resultsStream: AsyncStream<TranscriptionResult>
    private let continuation: AsyncStream<TranscriptionResult>.Continuation

    init() {
        var c: AsyncStream<TranscriptionResult>.Continuation!
        self.resultsStream = AsyncStream { cont in c = cont }
        self.continuation = c
    }

    var results: AsyncStream<TranscriptionResult> { resultsStream }

    func start(with input: AsyncStream<AudioChunk>) async throws {
        let transcriber = SpeechTranscriber(locale: .current,
                                            transcriptionOptions: [],
                                            reportingOptions: [.volatileResults],
                                            attributeOptions: [])
        self.transcriber = transcriber
        self.analyzer = SpeechAnalyzer(modules: [transcriber])

        let pair = AsyncStream<AnalyzerInput>.makeStream()
        self.inputSequence = pair.stream
        self.inputBuilder = pair.continuation

        // results forwarding
        let rTask = Task { [weak self] in
            guard let self else { return }
            do {
                for try await result in transcriber.results {
                    let text = result.text
                    let isFinal = result.isFinal
                    self.continuation.yield(.init(text: String(text.characters), isFinal: isFinal))
                }
            } catch {
                // ignore for now
            }
        }
        tasks.append(rTask)

        // audio feeding placeholder
        let fTask = Task { [weak self] in
            guard let self, let builder = self.inputBuilder else { return }
            for await _ in input {
                if Task.isCancelled { break }
                // Future: convert AudioChunk -> AVAudioPCMBuffer and yield
                // builder.yield(AnalyzerInput(buffer: buffer))
            }
            builder.finish()
        }
        tasks.append(fTask)

        if let seq = self.inputSequence {
            try await analyzer?.start(inputSequence: seq)
        }
    }

    func stop() async {
        inputBuilder?.finish()
        try? await analyzer?.finalizeAndFinishThroughEndOfInput()
        tasks.forEach { $0.cancel() }
        tasks.removeAll(keepingCapacity: false)
        continuation.finish()
        analyzer = nil
        transcriber = nil
        inputSequence = nil
        inputBuilder = nil
    }
}

@available(iOS 26, *)
final class IOSAssetManager: AssetManaging {

    func ensureAssetsAvailable() async -> Bool {
        let current = Locale.current
        let installed = await Set(SpeechTranscriber.installedLocales)
        return installed.map { $0.identifier(.bcp47) }.contains(current.identifier(.bcp47))
    }

    func installIfNeeded() async throws -> Bool {
        let transcriber = SpeechTranscriber(locale: .current,
                                            transcriptionOptions: [],
                                            reportingOptions: [],
                                            attributeOptions: [])
        if let downloader = try await AssetInventory.assetInstallationRequest(supporting: [transcriber]) {
            try await downloader.downloadAndInstall()
            return true
        }
        return false
    }
}

@available(iOS 26, *)
extension IOSSpeechEngine: @unchecked Sendable {}
@available(iOS 26, *)
extension IOSAssetManager: @unchecked Sendable {}

#endif


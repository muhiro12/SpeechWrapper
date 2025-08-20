import Foundation

#if os(iOS) && canImport(Speech)
import Speech
@preconcurrency import AVFoundation

/// iOS 17/18 compatible engine using SFSpeechRecognizer.
final class LegacySpeechEngine: TranscriptionEngine {
    private var recognizer: SFSpeechRecognizer?
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?

    private let resultsStream: AsyncStream<TranscriptionResult>
    private let continuation: AsyncStream<TranscriptionResult>.Continuation

    init(locale: Locale = .current) {
        var c: AsyncStream<TranscriptionResult>.Continuation!
        self.resultsStream = AsyncStream { cont in c = cont }
        self.continuation = c
        self.recognizer = SFSpeechRecognizer(locale: Locale(identifier: locale.identifier))
    }

    var results: AsyncStream<TranscriptionResult> { resultsStream }

    func start(with input: AsyncStream<AudioChunk>) async throws {
        let auth = await withCheckedContinuation { (cont: CheckedContinuation<SFSpeechRecognizerAuthorizationStatus, Never>) in
            SFSpeechRecognizer.requestAuthorization { status in cont.resume(returning: status) }
        }
        guard auth == .authorized else { throw TranscriptionError.notAuthorized }

        guard let recognizer, recognizer.isAvailable else {
            throw TranscriptionError.setupFailed
        }

        let req = SFSpeechAudioBufferRecognitionRequest()
        req.shouldReportPartialResults = true
        self.request = req

        self.task = recognizer.recognitionTask(with: req) { [weak self] result, error in
            guard let self else { return }
            if let _ = error {
                self.continuation.finish()
                return
            }
            if let result {
                let text = result.bestTranscription.formattedString
                self.continuation.yield(.init(text: text, isFinal: result.isFinal))
                if result.isFinal { self.continuation.finish() }
            }
        }

        // Feed audio chunks into the request
        Task.detached { [weak self] in
            guard let self, let req = self.request else { return }
            for await chunk in input {
                if Task.isCancelled { break }
                let frames = chunk.bytes.count / MemoryLayout<Float>.size
                guard frames > 0 else { continue }
                let format = AVAudioFormat(standardFormatWithSampleRate: chunk.sampleRate, channels: 1)!
                guard let pcm = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(frames)) else { continue }
                pcm.frameLength = AVAudioFrameCount(frames)
                chunk.bytes.withUnsafeBytes { raw in
                    guard let src = raw.bindMemory(to: Float.self).baseAddress else { return }
                    pcm.floatChannelData![0].update(from: src, count: frames)
                }
                req.append(pcm)
            }
        }
    }

    func stop() async {
        request?.endAudio()
        task?.cancel()
        continuation.finish()
        task = nil
        request = nil
    }
}

extension LegacySpeechEngine: @unchecked Sendable {}

#endif


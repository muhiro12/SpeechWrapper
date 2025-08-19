import Foundation

#if os(iOS)
@preconcurrency import AVFoundation

final class MicrophoneInput: AudioInput {
    private let engine = AVAudioEngine()
    private var cont: AsyncStream<AudioChunk>.Continuation!
    private let streamImpl: AsyncStream<AudioChunk>
    private var isRunning = false

    init() {
        var c: AsyncStream<AudioChunk>.Continuation!
        self.streamImpl = AsyncStream { continuation in c = continuation }
        self.cont = c
    }

    var chunks: AsyncStream<AudioChunk> { streamImpl }

    func start() async throws {
        guard !isRunning else { return }
        // Request microphone permission
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .measurement, options: [.duckOthers])
        try session.setActive(true)

        let granted: Bool = await withCheckedContinuation { continuation in
            session.requestRecordPermission { ok in continuation.resume(returning: ok) }
        }
        guard granted else { throw TranscriptionError.notAuthorized }

        // Configure input format and tap
        let input = engine.inputNode
        let inputFormat = input.inputFormat(forBus: 0)
        let targetFormat = AVAudioFormat(standardFormatWithSampleRate: inputFormat.sampleRate, channels: 1)!
        let converter = AVAudioConverter(from: inputFormat, to: targetFormat)

        input.removeTap(onBus: 0)
        input.installTap(onBus: 0, bufferSize: 2048, format: inputFormat) { [weak self] buffer, _ in
            guard let self else { return }
            // Convert to Float32 mono if needed
            let outCapacity = AVAudioFrameCount(buffer.frameLength)
            guard let outBuf = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: outCapacity) else { return }
            outBuf.frameLength = outCapacity
            var error: NSError?
            let inputBlock: AVAudioConverterInputBlock = { _, outStatus in
                outStatus.pointee = .haveData
                return buffer
            }
            if let converter, converter.inputFormat != converter.outputFormat {
                _ = converter.convert(to: outBuf, error: &error, withInputFrom: inputBlock)
                if error != nil { return }
            } else {
                // Same format; just copy reference
                outBuf.frameLength = buffer.frameLength
                if let src = buffer.floatChannelData, let dst = outBuf.floatChannelData {
                    let frames = Int(buffer.frameLength)
                    // Downmix first channel only if multichannel
                    dst[0].update(from: src[0], count: frames)
                }
            }

            guard let dataPtr = outBuf.floatChannelData?[0] else { return }
            let frames = Int(outBuf.frameLength)
            let byteCount = frames * MemoryLayout<Float>.size
            let data = Data(bytes: dataPtr, count: byteCount)
            let chunk = AudioChunk(bytes: data, sampleRate: targetFormat.sampleRate, channels: 1)
            self.cont.yield(chunk)
        }

        try engine.start()
        isRunning = true
    }

    func stop() async {
        guard isRunning else { cont.finish(); return }
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        isRunning = false
        cont.finish()
    }
}

extension MicrophoneInput: @unchecked Sendable {}

#endif

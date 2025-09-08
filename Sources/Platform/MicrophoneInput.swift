import Foundation

#if os(iOS)
@preconcurrency import AVFoundation
import AVFAudio

final class MicrophoneInput: AudioInput {
    private let engine = AVAudioEngine()
    private var continuation: AsyncStream<AudioChunk>.Continuation!
    private let stream: AsyncStream<AudioChunk>
    private var isRunning = false

    init() {
        var tempContinuation: AsyncStream<AudioChunk>.Continuation!
        self.stream = AsyncStream { continuation in
            tempContinuation = continuation
        }
        self.continuation = tempContinuation
    }

    var chunks: AsyncStream<AudioChunk> { stream }

    func start() async throws {
        guard !isRunning else {
            return
        }
        // Request microphone permission
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .measurement, options: [.duckOthers])
        try session.setActive(true)

        let granted: Bool = await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { permissionGranted in
                continuation.resume(returning: permissionGranted)
            }
        }
        guard granted else {
            throw TranscriptionError.notAuthorized
        }

        // Configure input format and tap
        let input = engine.inputNode
        let inputFormat = input.inputFormat(forBus: 0)
        let targetFormat = AVAudioFormat(standardFormatWithSampleRate: inputFormat.sampleRate, channels: 1)!
        let converter = AVAudioConverter(from: inputFormat, to: targetFormat)

        input.removeTap(onBus: 0)
        input.installTap(onBus: 0, bufferSize: 2048, format: inputFormat) { [weak self] buffer, _ in
            guard let self else {
                return
            }
            // Convert to Float32 mono if needed
            let outCapacity = AVAudioFrameCount(buffer.frameLength)
            guard let outputBuffer = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: outCapacity) else {
                return
            }
            outputBuffer.frameLength = outCapacity
            var error: NSError?
            let box = _PCMBufferBox(buffer: buffer)
            let inputBlock: AVAudioConverterInputBlock = { _, outStatus in
                outStatus.pointee = .haveData
                return box.buffer
            }
            if let converter, converter.inputFormat != converter.outputFormat {
                _ = converter.convert(to: outputBuffer, error: &error, withInputFrom: inputBlock)
                if error != nil {
                    return
                }
            } else {
                // Same format; just copy reference
                outputBuffer.frameLength = buffer.frameLength
                if let sourceChannels = buffer.floatChannelData, let destinationChannels = outputBuffer.floatChannelData {
                    let frames = Int(buffer.frameLength)
                    // Downmix first channel only if multichannel
                    destinationChannels[0].update(from: sourceChannels[0], count: frames)
                }
            }

            guard let dataPtr = outputBuffer.floatChannelData?[0] else {
                return
            }
            let frames = Int(outputBuffer.frameLength)
            let byteCount = frames * MemoryLayout<Float>.size
            let data = Data(bytes: dataPtr, count: byteCount)
            let chunk = AudioChunk(bytes: data, sampleRate: targetFormat.sampleRate, channels: 1)
            self.continuation.yield(chunk)
        }

        try engine.start()
        isRunning = true
    }

    func stop() async {
        guard isRunning else {
            continuation.finish()
            return
        }
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        isRunning = false
        continuation.finish()
    }
}

private struct _PCMBufferBox: @unchecked Sendable {
    let buffer: AVAudioPCMBuffer
}

extension MicrophoneInput: @unchecked Sendable {}

#endif

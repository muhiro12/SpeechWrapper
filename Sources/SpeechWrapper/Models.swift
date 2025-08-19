import Foundation

/// Domain errors unified for the library.
/// - Note: Kept stable to avoid leaking Apple private types.
@available(iOS 26, *)
enum TranscriptionError: Error, Equatable, Sendable {
    case notAuthorized
    case audioUnavailable
    case modelUnavailable
    case setupFailed
    case analyzerFailed
    case transcriberFailed
    case alreadyRunning
    case notRunning
    case cancelled
    case unsupportedPlatform
    case assetInstallFailed
    case unknown
}

/// A unit of audio data independent from platform frameworks.
@available(iOS 26, *)
struct AudioChunk: Sendable, Equatable {
    public var bytes: Data
    public var sampleRate: Double
    public var channels: Int
    public var isFinal: Bool

    public init(bytes: Data, sampleRate: Double, channels: Int, isFinal: Bool = false) {
        self.bytes = bytes
        self.sampleRate = sampleRate
        self.channels = channels
        self.isFinal = isFinal
    }
}

/// Transcription result carrying interim and final texts.
@available(iOS 26, *)
struct TranscriptionResult: Sendable, Equatable {
    public let text: String
    public let isFinal: Bool

    public init(text: String, isFinal: Bool) {
        self.text = text
        self.isFinal = isFinal
    }
}

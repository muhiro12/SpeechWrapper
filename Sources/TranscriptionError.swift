import Foundation

/// Domain errors unified for the library.
/// - Note: Kept stable to avoid leaking Apple private types.
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

// Provide human-friendly messages without exposing the enum publicly.
extension TranscriptionError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .notAuthorized:
            return "Microphone access is not authorized."
        case .audioUnavailable:
            return "Audio input is unavailable."
        case .modelUnavailable:
            return "Required on-device speech model is unavailable."
        case .setupFailed:
            return "Failed to set up the transcription pipeline."
        case .analyzerFailed:
            return "Speech analyzer failed."
        case .transcriberFailed:
            return "Speech transcriber failed."
        case .alreadyRunning:
            return "Transcription is already running."
        case .notRunning:
            return "Transcription is not running."
        case .cancelled:
            return "Operation was cancelled."
        case .unsupportedPlatform:
            return "Unsupported platform."
        case .assetInstallFailed:
            return "Failed to install required assets."
        case .unknown:
            return "An unknown error occurred."
        }
    }
}

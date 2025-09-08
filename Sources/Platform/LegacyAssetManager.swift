import Foundation

#if os(iOS) && canImport(Speech)
import Speech

/// Legacy assets simply ensure speech permission is granted.
final class LegacyAssetManager: AssetManaging {
    private let locale: Locale
    init(locale: Locale) { self.locale = locale }
    func ensureAssetsAvailable() async -> Bool {
        let status = await withCheckedContinuation { (continuation: CheckedContinuation<SFSpeechRecognizerAuthorizationStatus, Never>) in
            SFSpeechRecognizer.requestAuthorization { authorizationStatus in
                continuation.resume(returning: authorizationStatus)
            }
        }
        return status == .authorized
    }

    func installIfNeeded() async throws -> Bool {
        let status = await withCheckedContinuation { (continuation: CheckedContinuation<SFSpeechRecognizerAuthorizationStatus, Never>) in
            SFSpeechRecognizer.requestAuthorization { authorizationStatus in
                continuation.resume(returning: authorizationStatus)
            }
        }
        return status == .authorized
    }
}

extension LegacyAssetManager: @unchecked Sendable {}

#endif

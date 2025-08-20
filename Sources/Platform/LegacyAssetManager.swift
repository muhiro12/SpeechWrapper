import Foundation

#if os(iOS) && canImport(Speech)
import Speech

/// Legacy assets simply ensure speech permission is granted.
final class LegacyAssetManager: AssetManaging {
    private let locale: Locale
    init(locale: Locale) { self.locale = locale }
    func ensureAssetsAvailable() async -> Bool {
        let status = await withCheckedContinuation { (cont: CheckedContinuation<SFSpeechRecognizerAuthorizationStatus, Never>) in
            SFSpeechRecognizer.requestAuthorization { s in cont.resume(returning: s) }
        }
        return status == .authorized
    }

    func installIfNeeded() async throws -> Bool {
        let status = await withCheckedContinuation { (cont: CheckedContinuation<SFSpeechRecognizerAuthorizationStatus, Never>) in
            SFSpeechRecognizer.requestAuthorization { s in cont.resume(returning: s) }
        }
        return status == .authorized
    }
}

extension LegacyAssetManager: @unchecked Sendable {}

#endif


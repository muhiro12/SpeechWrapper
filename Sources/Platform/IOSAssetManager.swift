import Foundation

#if os(iOS) && canImport(Speech)
import Speech

@available(iOS 26, *)
final class IOSAssetManager: AssetManaging {
    private let locale: Locale

    init(locale: Locale) { self.locale = locale }

    func ensureAssetsAvailable() async -> Bool {
        let current = locale
        let installed = await Set(SpeechTranscriber.installedLocales)
        return installed.map { $0.identifier(.bcp47) }.contains(current.identifier(.bcp47))
    }

    func installIfNeeded() async throws -> Bool {
        let transcriber = SpeechTranscriber(locale: locale,
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
extension IOSAssetManager: @unchecked Sendable {}

#endif


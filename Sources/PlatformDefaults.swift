import Foundation

enum PlatformDefaults {
    static func makeEngine(locale: Locale, forceLegacy: Bool = false) -> any TranscriptionEngine {
        #if os(iOS) && canImport(Speech)
        if #available(iOS 26, *), !forceLegacy {
            return IOSSpeechEngine(locale: locale)
        } else {
            return LegacySpeechEngine(locale: locale)
        }
        #else
        return NoopEngine()
        #endif
    }

    static func makeAssets(locale: Locale, forceLegacy: Bool = false) -> any AssetManaging {
        #if os(iOS) && canImport(Speech)
        if #available(iOS 26, *), !forceLegacy {
            return IOSAssetManager(locale: locale)
        } else {
            return LegacyAssetManager(locale: locale)
        }
        #else
        return NoopAssets()
        #endif
    }

    static func makeDefaultAudioInput() -> any AudioInput {
        #if os(iOS)
        return MicrophoneInput()
        #else
        return NoopMicrophone()
        #endif
    }
}


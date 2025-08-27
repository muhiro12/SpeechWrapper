import Foundation

public struct SpeechClientSettings: Sendable, Equatable {
    public var locale: Locale?
    public var useLegacy: Bool

    public init(locale: Locale? = nil,
                useLegacy: Bool = false) {
        self.locale = locale
        self.useLegacy = useLegacy
    }
}

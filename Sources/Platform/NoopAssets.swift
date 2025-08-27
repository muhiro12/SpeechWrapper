import Foundation

final class NoopAssets: AssetManaging {
    func ensureAssetsAvailable() async -> Bool { true }
    func installIfNeeded() async throws -> Bool { true }
}

extension NoopAssets: @unchecked Sendable {}

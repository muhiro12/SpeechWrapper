import Foundation

/// Asset manager abstraction for on-device models.
protocol AssetManaging: Sendable {
    /// Returns true if required assets are already available.
    func ensureAssetsAvailable() async -> Bool
    /// Attempts to install missing assets. Returns true on success.
    func installIfNeeded() async throws -> Bool
}

import Foundation

/// A unit of audio data independent from platform frameworks.
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


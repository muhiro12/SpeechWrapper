// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "SpeechTranscriptionKit",
    platforms: [
        .iOS(.v26)
    ],
    products: [
        .library(name: "SpeechTranscriptionKit", targets: ["SpeechTranscriptionKit"])
    ],
    targets: [
        .target(name: "SpeechTranscriptionKit"),
        .testTarget(name: "SpeechTranscriptionKitTests", dependencies: ["SpeechTranscriptionKit"])
    ]
)

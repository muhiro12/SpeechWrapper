// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.
import PackageDescription

let package = Package(
    name: "SpeechWrapper",
    platforms: [
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "SpeechWrapper",
            targets: ["SpeechWrapper"]
        )
    ],
    targets: [
        .target(
            name: "SpeechWrapper"
        ),
        .testTarget(
            name: "SpeechWrapperTests",
            dependencies: ["SpeechWrapper"]
        )
    ]
)

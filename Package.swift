// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "VoiceFlow",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "VoiceFlowProtocol", targets: ["VoiceFlowProtocol"]),
    ],
    targets: [
        .target(
            name: "VoiceFlowProtocol",
            path: "Sources/VoiceFlowProtocol"
        ),
        .executableTarget(
            name: "VoiceFlowApp",
            dependencies: ["VoiceFlowProtocol"],
            path: "Sources/VoiceFlowApp"
        ),
        .executableTarget(
            name: "VoiceFlowSTT",
            dependencies: ["VoiceFlowProtocol"],
            path: "Sources/VoiceFlowSTT"
        ),
        .executableTarget(
            name: "VoiceFlowRefiner",
            dependencies: ["VoiceFlowProtocol"],
            path: "Sources/VoiceFlowRefiner"
        ),
        .testTarget(
            name: "VoiceFlowTests",
            dependencies: ["VoiceFlowApp", "VoiceFlowRefiner"],
            path: "Tests/VoiceFlowTests"
        ),
    ]
)

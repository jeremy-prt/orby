// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "ScreenshotMini",
    platforms: [
        .macOS(.v26)
    ],
    targets: [
        .executableTarget(
            name: "ScreenshotMini",
            path: "Sources/ScreenshotMini"
        )
    ]
)

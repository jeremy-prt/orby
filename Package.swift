// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "Orby",
    platforms: [
        .macOS(.v15)
    ],
    targets: [
        .executableTarget(
            name: "Orby",
            path: "Sources/Orby",
            swiftSettings: [
                .unsafeFlags(["-F", "Frameworks"])
            ],
            linkerSettings: [
                .unsafeFlags(["-F", "Frameworks", "-framework", "Sparkle",
                              "-Xlinker", "-rpath", "-Xlinker", "@executable_path/../Frameworks"])
            ]
        )
    ]
)

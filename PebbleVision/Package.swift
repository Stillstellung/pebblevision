// swift-tools-version: 5.9
// Alternative build configuration using Swift Package Manager.
// This can be used instead of the .xcodeproj if preferred.

import PackageDescription

let package = Package(
    name: "PebbleVision",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "PebbleVision", targets: ["PebbleVision"])
    ],
    targets: [
        .executableTarget(
            name: "PebbleVision",
            path: "PebbleVision",
            resources: [
                .process("Resources/Assets.xcassets")
            ]
        )
    ]
)

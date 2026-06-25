// swift-tools-version: 6.0

import PackageDescription
import Foundation

let package = Package(
    name: "VPStudio",
    platforms: [
        .visionOS(.v2),
        .macOS(.v15),
    ],
    products: [
        .library(name: "VPStudio", targets: ["VPStudio"]),
    ],
    dependencies: [
        .package(url: "https://github.com/groue/GRDB.swift", from: "7.0.0"),
        .package(url: "https://github.com/kingslay/KSPlayer", from: "2.2.0"),
        .package(url: "https://github.com/huggingface/swift-transformers", .upToNextMinor(from: "1.1.0")),
        .package(url: "https://github.com/apple/swift-testing", from: "0.12.0"),
    ],
    targets: [
        .target(
            name: "RealityKitContent",
            path: "Packages/RealityKitContent/Sources/RealityKitContent",
            resources: [.process("RealityKitContent.rkassets")]
        ),
        .target(
            name: "VPStudio",
            dependencies: [
                "RealityKitContent",
                .product(name: "GRDB", package: "GRDB.swift"),
                .product(name: "KSPlayer", package: "KSPlayer"),
                .product(name: "Hub", package: "swift-transformers"),
                .product(name: "Tokenizers", package: "swift-transformers"),
            ],
            path: "VPStudio",
            exclude: [
                "Assets.xcassets",
                "App/VPStudioApp.swift",
            ],
            resources: [
                .process("Resources"),
            ],
            swiftSettings: [
                // `isolated deinit` is stable on Xcode 26/27 (Swift 6.2) but still gated
                // behind an experimental flag on the CI toolchain (Xcode 16.x / Swift 6.1).
                // Enabling it keeps APMPInjector / HeadTracker compiling on both toolchains.
                .enableExperimentalFeature("IsolatedDeinit"),
            ]
        ),
        .testTarget(
            name: "VPStudioTests",
            dependencies: [
                "VPStudio",
                .product(name: "Testing", package: "swift-testing"),
            ],
            path: "VPStudioTests",
        ),
    ]
)

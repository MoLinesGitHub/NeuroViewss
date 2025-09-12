// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "NVAIKit",
    platforms: [
        .iOS(.v15),
        .macOS(.v12)
    ],
    products: [
        .library(
            name: "NVAIKit",
            targets: ["NVAIKit"]
        ),
    ],
    targets: [
        .target(
            name: "NVAIKit",
            dependencies: [],
            linkerSettings: [
                .linkedFramework("AVFoundation", .when(platforms: [.iOS, .macOS])),
                .linkedFramework("CoreImage", .when(platforms: [.iOS, .macOS])),
                .linkedFramework("Vision", .when(platforms: [.iOS, .macOS])),
                .linkedFramework("Photos", .when(platforms: [.iOS, .macOS]))
            ]
        ),
        .testTarget(
            name: "NVAIKitTests",
            dependencies: ["NVAIKit"],
            exclude: [
                "IntegrationTests.swift.disabled",
                "PerformanceTests.swift.disabled",
                "ComponentTests.swift.disabled",
                "LiveAIProcessorTests.swift.disabled"
            ]
        ),
    ]
)

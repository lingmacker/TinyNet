// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "TinyNet",
    platforms: [
        .macOS(.v13),
    ],
    products: [
        .library(name: "TinyNetCore", targets: ["TinyNetCore"]),
    ],
    targets: [
        .target(
            name: "TinyNetCore",
            path: "TinyNet/Core",
            sources: [
                "InterfaceFilterRule.swift",
                "NetSpeedCalculator.swift",
                "NetSpeedModels.swift",
            ]
        ),
        .testTarget(
            name: "TinyNetCoreTests",
            dependencies: ["TinyNetCore"],
            path: "Tests/TinyNetCoreTests"
        ),
    ]
)

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
            path: "src/core",
            exclude: ["NetSpeedViewModel.swift"],
            sources: [
                "InterfaceFilterRule.swift",
                "NetSpeedCalculator.swift",
                "NetSpeedModels.swift",
            ]
        ),
        .testTarget(
            name: "TinyNetCoreTests",
            dependencies: ["TinyNetCore"],
            path: "tests/swift"
        ),
    ]
)

// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "TinyNetCore",
    platforms: [.macOS(.v13)],
    targets: [
        .target(
            name: "TinyNetCore",
            path: "TinyNet",
            exclude: ["TinyNet.swift", "View", "Resources", "Assets.xcassets", "Model/NetSpeedViewModel.swift"],
            sources: ["Core", "Model/AppNetworkMonitor.swift"]
        ),
        .testTarget(name: "TinyNetCoreTests", dependencies: ["TinyNetCore"], path: "tests/TinyNetCoreTests"),
    ],
    swiftLanguageModes: [.v5]
)

// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "MemoRadar",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "MemoRadarCore"),
        .executableTarget(name: "MemoRadar", dependencies: ["MemoRadarCore"]),
        .testTarget(name: "MemoRadarCoreTests", dependencies: ["MemoRadarCore"]),
    ]
)

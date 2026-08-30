// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MarmorEngine",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "MarmorEngine", targets: ["MarmorEngine"]),
        .library(name: "MarmorAudio", targets: ["MarmorAudio"]),
    ],
    targets: [
        .target(name: "MarmorEngine"),
        .testTarget(name: "MarmorEngineTests", dependencies: ["MarmorEngine"]),
        .target(name: "MarmorAudio"),
        .testTarget(name: "MarmorAudioTests", dependencies: ["MarmorAudio"]),
    ]
)

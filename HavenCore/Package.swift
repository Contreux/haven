// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "HavenCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "HavenCore", targets: ["HavenCore"]),
    ],
    targets: [
        .target(name: "HavenCore"),
        .testTarget(name: "HavenCoreTests", dependencies: ["HavenCore"]),
    ]
)

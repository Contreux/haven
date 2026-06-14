// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "HavenDesignSystem",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "HavenDesignSystem", targets: ["HavenDesignSystem"]),
    ],
    targets: [
        .target(
            name: "HavenDesignSystem",
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "HavenDesignSystemTests",
            dependencies: ["HavenDesignSystem"]
        ),
    ]
)

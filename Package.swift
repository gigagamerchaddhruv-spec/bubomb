// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Bubomb",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "Bubomb", targets: ["BubombApp"]),
        .executable(name: "BubombTests", targets: ["BubombTests"]),
        .library(name: "BubombCore", targets: ["BubombCore"]),
        .library(name: "BubombUI", targets: ["BubombUI"])
    ],
    dependencies: [],
    targets: [
        .target(
            name: "BubombCore",
            dependencies: [],
            path: "Sources/BubombCore"
        ),
        .target(
            name: "BubombUI",
            dependencies: ["BubombCore"],
            path: "Sources/BubombUI"
        ),
        .executableTarget(
            name: "BubombApp",
            dependencies: ["BubombCore", "BubombUI"],
            path: "Sources/BubombApp"
        ),
        .executableTarget(
            name: "BubombTests",
            dependencies: ["BubombCore"],
            path: "Tests/BubombCoreTests"
        )
    ]
)

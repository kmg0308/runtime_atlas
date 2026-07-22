// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "RuntimeAtlas",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(name: "RuntimeAtlasCore", targets: ["RuntimeAtlasCore"]),
        .executable(name: "RuntimeAtlas", targets: ["RuntimeAtlas"]),
        .executable(name: "runtime-atlas", targets: ["RuntimeAtlasCLI"]),
        .executable(name: "runtime-atlas-supervisor", targets: ["RuntimeAtlasSupervisor"]),
        .executable(name: "RuntimeAtlasSelfTest", targets: ["RuntimeAtlasSelfTest"])
    ],
    targets: [
        .target(name: "RuntimeAtlasCore"),
        .executableTarget(
            name: "RuntimeAtlas",
            dependencies: ["RuntimeAtlasCore"]
        ),
        .executableTarget(
            name: "RuntimeAtlasCLI",
            dependencies: ["RuntimeAtlasCore"]
        ),
        .executableTarget(name: "RuntimeAtlasSupervisor"),
        .executableTarget(
            name: "RuntimeAtlasSelfTest",
            dependencies: ["RuntimeAtlasCore"]
        ),
        .testTarget(
            name: "RuntimeAtlasCoreTests",
            dependencies: ["RuntimeAtlasCore"]
        )
    ]
)

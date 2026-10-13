// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Mori",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "Mori", targets: ["Mori"])],
    targets: [
        .target(name: "MoriCore"),
        .executableTarget(name: "Mori", dependencies: ["MoriCore"], resources: [.copy("Resources")]),
        .testTarget(name: "MoriCoreTests", dependencies: ["MoriCore"])
    ]
)

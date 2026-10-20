// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Archway",
    platforms: [.macOS(.v13)],
    targets: [
        .target(name: "WireGuardCore"),
        .executableTarget(name: "Archway", dependencies: ["WireGuardCore"]),
        .executableTarget(name: "ArchwayHelper", dependencies: ["WireGuardCore"]),
        .testTarget(name: "ArchwayTests", dependencies: ["Archway", "WireGuardCore", "ArchwayHelper"])
    ]
)

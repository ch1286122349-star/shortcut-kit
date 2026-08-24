// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ShortcutKitApp",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "ShortcutKitCore", targets: ["ShortcutKitCore"]),
        .executable(name: "ShortcutKitApp", targets: ["ShortcutKitApp"]),
    ],
    targets: [
        .target(name: "ShortcutKitCore"),
        .executableTarget(
            name: "ShortcutKitApp",
            dependencies: ["ShortcutKitCore"],
            resources: [.process("Resources")]
        ),
        .testTarget(name: "ShortcutKitCoreTests", dependencies: ["ShortcutKitCore"]),
    ]
)

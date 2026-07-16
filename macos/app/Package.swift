// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "CodexDreamSkinMenuBar",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "CodexDreamSkinMenuBar",
            targets: ["CodexDreamSkinMenuBar"]
        )
    ],
    targets: [
        .executableTarget(
            name: "CodexDreamSkinMenuBar",
            path: "Sources/CodexDreamSkinMenuBar"
        )
    ]
)

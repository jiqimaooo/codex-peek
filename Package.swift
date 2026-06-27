// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "CodexPeek",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "CodexPeek", targets: ["CodexPeek"])
    ],
    targets: [
        .executableTarget(
            name: "CodexPeek",
            path: "CodexPeek",
            exclude: ["App/Info.plist"]
        )
    ]
)

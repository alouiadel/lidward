// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "Lidward",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "Lidward", targets: ["Lidward"])
    ],
    targets: [
        .executableTarget(
            name: "Lidward",
            path: "Sources/Lidward"
        )
    ]
)

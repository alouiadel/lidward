// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "Lidward",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "Lidward", targets: ["Lidward"]),
        .executable(name: "LidwardHelper", targets: ["LidwardHelper"])
    ],
    targets: [
        .executableTarget(
            name: "Lidward",
            path: "Sources/Lidward",
            linkerSettings: [
                .linkedFramework("IOKit"),
                .linkedFramework("ServiceManagement"),
                .linkedFramework("SwiftUI")
            ]
        ),
        .executableTarget(
            name: "LidwardHelper",
            path: "Sources/LidwardHelper"
        )
    ]
)

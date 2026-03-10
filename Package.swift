// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "FloatTimer",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .executableTarget(
            name: "FloatTimer",
            path: "Sources/FloatTimer"
        )
    ]
)

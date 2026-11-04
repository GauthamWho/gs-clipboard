// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "GsClipboard",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "GsClipboard", targets: ["GsClipboard"])
    ],
    targets: [
        .executableTarget(
            name: "GsClipboard",
            path: "Sources/GsClipboard"
        )
    ]
)

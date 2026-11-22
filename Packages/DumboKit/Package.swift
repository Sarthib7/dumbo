// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "DumboKit",
    platforms: [.iOS("16.2"), .macOS(.v13)],
    products: [.library(name: "DumboKit", targets: ["DumboKit"])],
    targets: [
        .target(name: "DumboKit"),
        .testTarget(name: "DumboKitTests", dependencies: ["DumboKit"]),
    ]
)

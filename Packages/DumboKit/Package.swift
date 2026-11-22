// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "DumboKit",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [.library(name: "DumboKit", targets: ["DumboKit"])],
    targets: [
        .target(name: "DumboKit"),
        .testTarget(name: "DumboKitTests", dependencies: ["DumboKit"]),
    ]
)

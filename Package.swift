// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "KeySpa",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "KeySpa", targets: ["KeySpa"])],
    targets: [
        .executableTarget(name: "KeySpa"),
        .testTarget(name: "KeySpaTests", dependencies: ["KeySpa"])
    ]
)

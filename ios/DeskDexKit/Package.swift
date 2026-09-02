// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "DeskDexKit",
    // macOS도 올려둔 이유: 이러면 Xcode 없이 `swift test`만으로 도메인 로직
    // (NamingQueue 등)을 맥에서 바로 돌려볼 수 있다. SwiftData는 iOS 17과
    // macOS 14부터라 그 아래로는 못 내린다.
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "DeskDexKit", targets: ["DeskDexKit"]),
    ],
    targets: [
        .target(name: "DeskDexKit"),
        .testTarget(name: "DeskDexKitTests", dependencies: ["DeskDexKit"]),
    ]
)

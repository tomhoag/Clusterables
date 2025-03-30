// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Clusterables",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "Clusterables",
            targets: ["Clusterables"])
    ],
    dependencies: [
        .package(url: "https://github.com/NSHipster/DBSCAN", from: "0.0.2"),
        .package(url: "https://github.com/tomhoag/SwiftLintPlugin.git", branch: "main"),
    ],
    targets: [
        .target(
            name: "Clusterables",
            dependencies: [
                .product(name: "DBSCAN", package: "DBSCAN")
            ],
            plugins: [
                .plugin(name: "SwiftLintPlugin", package: "SwiftLintPlugin")
            ]
        )
    ]
)

// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Clusterables",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "Clusterables",
            targets: ["Clusterables"]),
    ],
    dependencies: [
        .package(url: "https://github.com/NSHipster/DBSCAN", from: "0.0.2")
    ],
    targets: [
        .target(
            name: "Clusterables",
            dependencies: [
                .product(name: "DBSCAN", package: "DBSCAN")
            ]
        ),
        .testTarget(
            name: "ClusterablesTests",
            dependencies: ["Clusterables"]),
    ]
)

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
        //.package(url: "https://github.com/tomhoag/KDTree-DBSCAN", from: "0.0.1")
        .package(path: "../KDTree-DBSCAN")
    ],
    targets: [
        .target(
            name: "Clusterables",
            dependencies: [
                .product(name: "DBSCAN", package: "KDTree-DBSCAN")
            ],
            exclude: [ "Example/" ]
        )
    ]
)

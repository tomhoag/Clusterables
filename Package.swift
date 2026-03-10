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
        .package(url: "https://github.com/Bersaelor/KDTree.git", from: "1.4.2")
    ],
    targets: [
        .target(
            name: "Clusterables",
            dependencies: [
                .product(name: "KDTree", package: "KDTree")
            ]
        )
    ]
)

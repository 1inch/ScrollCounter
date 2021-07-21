// swift-tools-version:5.1

import PackageDescription

let package = Package(
    name: "ScrollCounter",
    platforms: [
        .iOS(.v12),
    ],
    products: [
        .library(name: "ScrollCounter", targets: ["ScrollCounter"]),
    ],
    targets: [
        .target(name: "ScrollCounter", path: "ScrollCounter"),
    ]
)

// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SharePlayMock",
    platforms: [
        .visionOS(.v26)
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "SharePlayMock",
            targets: ["SharePlayMock"]),
    ],
    dependencies: [
        .package(
            url: "https://github.com/daltoniam/Starscream",
            from: "4.0.8")
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "SharePlayMock",
            dependencies: ["Starscream"]),
        .testTarget(
            name: "SharePlayMockTests",
            dependencies: ["SharePlayMock"]),
    ]
)

// swift-tools-version:4.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Unarchiver",
    products: [
        .library(name: "Unarchiver", targets: ["Unarchiver"])
    ],
    dependencies: [
        .package(url: "git@github.com:Octadero/CZlib.git", from: "0.0.5")
    ],
    targets: [
        .target(name: "Unarchiver", dependencies: []),
        .testTarget(name: "UnarchiverTests", dependencies: ["Unarchiver"])
    ]
)

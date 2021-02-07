// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "TextMate",
    products: [
        .library(name: "TextMate",
                 targets: ["TextMate"]),
    ],
    dependencies: [
        .package(url: "https://github.com/nerdsupremacist/SyntaxTree.git", from: "0.1.0"),
    ],
    targets: [
        .target(name: "TextMate",
                dependencies: ["SyntaxTree"]),
    ]
)

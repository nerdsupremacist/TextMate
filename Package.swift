// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "TextMate",
    platforms: [.iOS(.v13), .macOS(.v10_15)],
    products: [
        .library(name: "TextMate",
                 targets: ["TextMate"]),
    ],
    dependencies: [
        .package(url: "https://github.com/nerdsupremacist/SyntaxTree.git", .branch("main")),
    ],
    targets: [
        .target(name: "TextMate",
                dependencies: ["SyntaxTree"]),
    ]
)

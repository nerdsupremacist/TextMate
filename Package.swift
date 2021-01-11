// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "syntax-text-mate",
    platforms: [.iOS(.v13), .macOS(.v10_15)],
    products: [
        .library(name: "SyntaxTextMate",
                 targets: ["SyntaxTextMate"]),
    ],
    dependencies: [
        .package(url: "https://github.com/nerdsupremacist/Syntax.git", .branch("develop")),
    ],
    targets: [
        .target(name: "SyntaxTextMate",
                dependencies: ["Syntax"]),
        .testTarget(name: "SyntaxTextMateTests",
                    dependencies: ["SyntaxTextMate"]),
    ]
)

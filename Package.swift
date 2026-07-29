// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "WeBox",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "WeBoxCore", targets: ["WeBoxCore"]),
        .executable(name: "WeBox", targets: ["WeBoxApp"])
    ],
    targets: [
        .systemLibrary(name: "SQLite3", path: "Database/SQLite3"),
        .target(name: "WeBoxCore", dependencies: ["SQLite3"], path: ".", exclude: ["WeBoxApp", "Tests", "Docs", "Scripts", "Database/SQLite3", "README.md", "Package.swift"], sources: ["Core", "Models", "Database"]),
        .executableTarget(name: "WeBoxApp", dependencies: ["WeBoxCore"], path: "WeBoxApp"),
        .testTarget(name: "WeBoxTests", dependencies: ["WeBoxCore"], path: "Tests")
    ]
)

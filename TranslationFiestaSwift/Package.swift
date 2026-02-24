// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "TranslationFiestaSwift",
    platforms: [
        .macOS(.v14),
        .iOS(.v17),
        .tvOS(.v17),
        .watchOS(.v10)
    ],
    products: [
        .executable(
            name: "TranslationFiestaSwift",
            targets: ["TranslationFiestaSwift"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-log.git", from: "1.6.0"),
        .package(url: "https://github.com/apple/swift-collections.git", from: "1.2.0"),
        .package(url: "https://github.com/apple/swift-algorithms.git", from: "1.2.1"),
        .package(url: "https://github.com/CoreOffice/CoreXLSX.git", from: "0.14.2"),
        .package(url: "https://github.com/apple/swift-docc-plugin", from: "1.4.0"),
    ],
    targets: [
        .executableTarget(
            name: "TranslationFiestaSwift",
            dependencies: [
                .product(name: "Logging", package: "swift-log"),
                .product(name: "Collections", package: "swift-collections"),
                .product(name: "Algorithms", package: "swift-algorithms"),
                .product(name: "CoreXLSX", package: "CoreXLSX"),
            ],
            path: "Sources/TranslationFiestaSwift",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "TranslationFiestaSwiftTests",
            dependencies: ["TranslationFiestaSwift"],
            path: "Tests/TranslationFiestaSwiftTests"
        ),
    ]
)

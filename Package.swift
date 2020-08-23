// swift-tools-version:5.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "CombineRealm",
    platforms: [
        .macOS(.v10_15), .iOS(.v13), .tvOS(.v13), .watchOS(.v6)
    ],
    products: [
        .library(
            name: "CombineRealm",
            targets: ["CombineRealm"]),
    ],
    dependencies: [
        .package(url: "https://github.com/realm/realm-cocoa.git", .upToNextMajor(from: "5.0.0"))
    ],
    targets: [
        .target(
            name: "CombineRealm",
            dependencies: ["Realm", "RealmSwift"],
            path: "Sources"
        ),
        .testTarget(
            name: "CombineRealmTests",
            dependencies: ["CombineRealm"],
            path: "Tests"
        )
    ],
    swiftLanguageVersions: [.v5]
)

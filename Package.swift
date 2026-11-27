// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Waypoint",
    platforms: [
        // macOS is listed only so `swift test` runs on a Mac host. Observation needs macOS 14.
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(name: "WaypointCore", targets: ["WaypointCore"]),
        .library(name: "Waypoint", targets: ["Waypoint"]),
        .library(name: "WaypointUIKit", targets: ["WaypointUIKit"]),
    ],
    dependencies: [
        // Test doubles for the test targets only; no product depends on it, so apps never fetch
        // it.
        .package(url: "https://github.com/joeoct-oss/Understudy", from: "1.0.1")
    ],
    targets: [
        // UI-agnostic state engine. Foundation and Observation only, so it builds and tests on
        // Linux.
        .target(name: "WaypointCore"),
        // The unified log and signpost handler. Internal: `Waypoint` and the `WaypointUIKit`
        // placeholder depend on it and re-export it. Its files are wrapped in `#if canImport(os)`,
        // so it compiles empty on Linux.
        .target(name: "WaypointOSLog", dependencies: ["WaypointCore"]),
        // Coordinators with screens and the SwiftUI renderers; the UIKit renderers join it. Its
        // SwiftUI files are wrapped in `#if canImport(SwiftUI)` and its UIKit files in
        // `#if canImport(UIKit)`, so it compiles empty on Linux and without UIKit on macOS.
        .target(name: "Waypoint", dependencies: ["WaypointCore", "WaypointOSLog"]),
        // Placeholder, to be removed: the UIKit renderers are designed into `Waypoint`. Its
        // files are wrapped in `#if canImport(UIKit)`, so it compiles empty on Linux.
        .target(name: "WaypointUIKit", dependencies: ["WaypointCore", "WaypointOSLog"]),
        // Shared fixtures for the test targets. Internal test code, not a product.
        .target(
            name: "WaypointTestSupport",
            dependencies: ["WaypointCore", .product(name: "Understudy", package: "Understudy")],
            path: "Tests/WaypointTestSupport"
        ),
        .testTarget(
            name: "WaypointCoreTests",
            dependencies: ["WaypointCore", "WaypointTestSupport", .product(name: "Understudy", package: "Understudy")]
        ),
        // Renderer tests compile empty where SwiftUI or UIKit is missing, like the renderers
        // themselves.
        .testTarget(
            name: "WaypointTests",
            dependencies: ["Waypoint", "WaypointTestSupport", .product(name: "Understudy", package: "Understudy")]
        ),
        .testTarget(
            name: "WaypointUIKitTests",
            dependencies: ["WaypointUIKit", "WaypointTestSupport", .product(name: "Understudy", package: "Understudy")]
        ),
        // Unified log tests compile empty where `os` is missing, like the target itself.
        .testTarget(
            name: "WaypointOSLogTests",
            dependencies: ["WaypointOSLog", "WaypointTestSupport", .product(name: "Understudy", package: "Understudy")]
        ),
    ],
    swiftLanguageModes: [.v6]
)

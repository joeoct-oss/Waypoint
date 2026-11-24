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
        .target(name: "WaypointTestSupport", dependencies: ["WaypointCore"], path: "Tests/WaypointTestSupport"),
        .testTarget(name: "WaypointCoreTests", dependencies: ["WaypointCore", "WaypointTestSupport"]),
        // Renderer tests compile empty where SwiftUI or UIKit is missing, like the renderers
        // themselves.
        .testTarget(name: "WaypointTests", dependencies: ["Waypoint", "WaypointTestSupport"]),
        .testTarget(name: "WaypointUIKitTests", dependencies: ["WaypointUIKit", "WaypointTestSupport"]),
        // Unified log tests compile empty where `os` is missing, like the target itself.
        .testTarget(name: "WaypointOSLogTests", dependencies: ["WaypointOSLog", "WaypointTestSupport"]),
    ],
    swiftLanguageModes: [.v6]
)

// swift-tools-version: 6.0
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
        // UI-agnostic state engine. Foundation and Observation only, so it builds and tests on Linux.
        .target(name: "WaypointCore"),
        // SwiftUI renderer. Its files are wrapped in `#if canImport(SwiftUI)`, so it compiles empty on Linux.
        .target(name: "Waypoint", dependencies: ["WaypointCore"]),
        // UIKit renderer. Its files are wrapped in `#if canImport(UIKit)`, so it compiles empty on Linux.
        .target(name: "WaypointUIKit", dependencies: ["WaypointCore"]),
        .testTarget(name: "WaypointCoreTests", dependencies: ["WaypointCore"]),
    ],
    swiftLanguageModes: [.v6]
)

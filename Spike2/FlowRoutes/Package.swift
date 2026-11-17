// swift-tools-version: 6.0
// Throwaway spike C (flow routes). Never merged.
import PackageDescription

let package = Package(
    name: "FlowRoutes",
    platforms: [.iOS(.v17), .macOS(.v14)],
    dependencies: [.package(name: "Waypoint", path: "../..")],
    targets: [
        .target(name: "FlowRoutes", dependencies: [.product(name: "WaypointCore", package: "Waypoint")]),
        .testTarget(name: "FlowRoutesTests", dependencies: ["FlowRoutes"]),
    ],
    swiftLanguageModes: [.v6]
)

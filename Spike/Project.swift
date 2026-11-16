import ProjectDescription

let settings: Settings = .settings(base: ["SWIFT_VERSION": "6.0", "SWIFT_STRICT_CONCURRENCY": "complete"])

let project = Project(
    name: "RendererSpike",
    targets: [
        .target(
            name: "RendererSpike",
            destinations: .iOS,
            product: .app,
            bundleId: "io.github.joeoct91.waypoint.spike",
            deploymentTargets: .iOS("17.0"),
            infoPlist: .extendingDefault(with: [
                "UILaunchScreen": [:],
                "CFBundleURLTypes": [["CFBundleURLName": "spike", "CFBundleURLSchemes": ["spike"]]],
            ]),
            sources: ["Sources/**"],
            settings: settings
        ),
        .target(
            name: "RendererSpikeUITests",
            destinations: .iOS,
            product: .uiTests,
            bundleId: "io.github.joeoct91.waypoint.spike.uitests",
            deploymentTargets: .iOS("17.0"),
            sources: ["UITests/**"],
            dependencies: [.target(name: "RendererSpike")],
            settings: settings
        ),
    ]
)

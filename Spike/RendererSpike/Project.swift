import ProjectDescription

let settings: Settings = .settings(base: [
    "SWIFT_VERSION": "5.0",
    "DEVELOPMENT_TEAM": "",
    "CODE_SIGN_IDENTITY": "-",
])

let project = Project(
    name: "RendererSpike",
    targets: [
        .target(
            name: "RendererSpike",
            destinations: [.iPhone],
            product: .app,
            bundleId: "dev.waypoint.spike250",
            deploymentTargets: .iOS("17.0"),
            infoPlist: .extendingDefault(with: ["UILaunchScreen": [:]]),
            sources: ["Sources/**"],
            settings: settings
        ),
        .target(
            name: "RendererSpikeUITests",
            destinations: [.iPhone],
            product: .uiTests,
            bundleId: "dev.waypoint.spike250.uitests",
            deploymentTargets: .iOS("17.0"),
            sources: ["UITests/**"],
            dependencies: [.target(name: "RendererSpike")],
            settings: settings
        ),
    ]
)

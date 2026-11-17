import ProjectDescription

let settings: Settings = .settings(base: ["SWIFT_VERSION": "6.0", "SWIFT_STRICT_CONCURRENCY": "complete"])

let testSettings: Settings = .settings(base: ["SWIFT_VERSION": "5.0", "SWIFT_STRICT_CONCURRENCY": "minimal"])

let project = Project(
    name: "ProposalSpike",
    targets: [
        .target(
            name: "ProposalSpike",
            destinations: [.iPhone, .iPad],
            product: .app,
            bundleId: "io.github.joeoct91.waypoint.proposalspike",
            deploymentTargets: .iOS("17.0"),
            infoPlist: .extendingDefault(with: [
                "UILaunchScreen": [:],
                "CFBundleURLTypes": [["CFBundleURLName": "spike", "CFBundleURLSchemes": ["spike"]]],
                "UIApplicationSceneManifest": ["UIApplicationSupportsMultipleScenes": true],
                "UISupportedInterfaceOrientations~ipad": [
                    "UIInterfaceOrientationPortrait", "UIInterfaceOrientationPortraitUpsideDown",
                    "UIInterfaceOrientationLandscapeLeft", "UIInterfaceOrientationLandscapeRight",
                ],
                "NSLocationWhenInUseUsageDescription": "Spike E shows a system permission alert.",
            ]),
            sources: ["Sources/**"],
            settings: settings
        ),
        .target(
            name: "ProposalSpikeUITests",
            destinations: [.iPhone, .iPad],
            product: .uiTests,
            bundleId: "io.github.joeoct91.waypoint.proposalspike.uitests",
            deploymentTargets: .iOS("17.0"),
            sources: ["UITests/**"],
            dependencies: [.target(name: "ProposalSpike")],
            settings: testSettings
        ),
    ]
)

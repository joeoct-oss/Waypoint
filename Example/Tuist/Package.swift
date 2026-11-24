// swift-tools-version: 6.2
//
//  Package.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

// The example app takes the Waypoint package through Tuist's own package integration, so the
// package's targets join Tuist's graph and their sources count in the hashes that selective
// testing uses (#324): a change in any of them runs the example app's tests again. Run
// `tuist install --path Example` before `tuist generate`; `scripts/test-mac.sh` does.
//
// Tuist writes the package's project, `Waypoint.xcodeproj` and `Derived/`, into the package root.
// Neither is committed. `scripts/test-mac.sh` moves them aside while it tests the package's own
// `Waypoint-Package` scheme, which xcodebuild can't find while a project sits next to
// `Package.swift`.

import PackageDescription

#if TUIST
import ProjectDescription

// SwiftPM gives every target of one package the same package name, so a `package` symbol of one
// module is visible to the others. Tuist builds the package's targets as Xcode targets, which
// share that name only when each sets it. Tuist also silences a package's warnings
// (`SWIFT_SUPPRESS_WARNINGS`), which clashes with warnings as errors, so Waypoint's own targets
// turn their warnings back on and keep them as errors, as every other build of the package does.
let waypointTargetSettings: Settings = .settings(base: [
    "SWIFT_PACKAGE_NAME": "Waypoint",
    "SWIFT_SUPPRESS_WARNINGS": "NO",
    "GCC_WARN_INHIBIT_ALL_WARNINGS": "NO",
    "SWIFT_TREAT_WARNINGS_AS_ERRORS": "YES",
])

let packageSettings = PackageSettings(
    targetSettings: [
        "WaypointCore": waypointTargetSettings,
        "WaypointOSLog": waypointTargetSettings,
        "Waypoint": waypointTargetSettings,
        "WaypointUIKit": waypointTargetSettings,
    ]
)
#endif

let package = Package(
    name: "WaypointExampleDependencies",
    dependencies: [
        .package(path: "../.."),
    ]
)

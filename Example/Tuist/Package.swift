// swift-tools-version: 6.2
//
//  Package.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

// Experiment: the example app takes the Waypoint package through Tuist's own package
// integration, so the package's targets join Tuist's graph and their sources count in the hashes
// that selective testing and the binary cache use. `tuist install --path Example` resolves it.

import PackageDescription

let package = Package(
    name: "WaypointExampleDependencies",
    dependencies: [
        .package(path: "../.."),
    ]
)

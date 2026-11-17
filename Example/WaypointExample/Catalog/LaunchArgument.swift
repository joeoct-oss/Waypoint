//
//  LaunchArgument.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <52625092+JoeOCT91@users.noreply.github.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

// The launch arguments that open a screen directly, such as `-branch uikit -flow sheet -kind swiftui`.
// UI tests pass them, and the app reads them through `UserDefaults`, which parses `-name value` pairs.
//
// Conformances:
// - `String` raw values, so each argument's name is its `UserDefaults` key.
enum LaunchArgument: String {
    case branch
    case flow
    case kind

    var flag: String {
        "-\(rawValue)"
    }
}

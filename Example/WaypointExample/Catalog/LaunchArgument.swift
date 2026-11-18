//
//  LaunchArgument.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

// The launch arguments that open a screen directly. `-signedIn YES` skips sign-in, `-guest YES`
// starts as a guest, `-lab YES` opens the Navigation Lab, `-branch uikit -flow sheet -kind swiftui`
// opens one of its entries, and `-splashSeconds 5` keeps the splash up longer, so a test can see
// it. UI tests pass them, and the app reads them through `UserDefaults`, which parses `-name value`
// pairs.
//
// Conformances:
// - `String` raw values, so each argument's name is its `UserDefaults` key.
enum LaunchArgument: String {
    case signedIn
    case guest
    case lab
    case branch
    case flow
    case kind
    case splashSeconds

    var flag: String {
        "-\(rawValue)"
    }
}

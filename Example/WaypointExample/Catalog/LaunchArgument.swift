//
//  LaunchArgument.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

// The launch arguments that open a screen directly. `-signedIn YES` skips sign-in, `-guest YES` starts as a
// guest, `-lab YES` opens the Navigation Lab, `-branch uikit -flow sheet -kind swiftui` opens one of its
// entries, and `-splashSeconds 5` keeps the splash up longer, so a test can see it. `-shopPath 1,2,3` pushes
// those products onto the shop in one change, and `-shopFollowUp popToRoot` makes one more change 150 ms
// into that push, while it still animates (`pop`, `popToRoot` or `link`). UI tests pass them, and the app
// reads them through `UserDefaults`, which parses `-name value` pairs.
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
    case shopPath
    case shopFollowUp

    var flag: String {
        "-\(rawValue)"
    }
}

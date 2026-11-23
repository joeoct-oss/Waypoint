//
//  LaunchArgument.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

// The launch arguments that set up a run. `-clearData YES` starts from a fresh install, `-signedIn
// YES` starts signed in, `-lab YES` opens the Navigation Lab, `-branch uikit -flow sheet -kind
// swiftui` opens one of its entries, `-splashSeconds 0` skips the splash, as UI tests do, and
// `-splashSeconds 5` keeps it up longer, so a test can see it. `-shopPath 1,2,3` pushes those
// products onto the shop in one change, and `-shopFollowUp popToRoot` makes one more change 150 ms
// into that push, while it still animates (`pop`, `popToRoot` or `link`). `-systemLinks YES` draws
// the product page's related link as a system `NavigationLink`, so a UI test can check how Waypoint
// reports one. `-missingDestination YES` makes that link push a reviews route the router knows but
// no screen of the stack draws, so a UI test can check the screen Waypoint shows instead.
// `-labReviewsSeconds 6` makes the Lab's demo reviews take that long to load, so a UI test has time
// to close the demo before they arrive, however slow the run. UI tests
// pass them, and the app reads them through `UserDefaults`, which parses `-name value` pairs.
//
// Conformances:
// - `String` raw values, so each argument's name is its `UserDefaults` key.
nonisolated enum LaunchArgument: String {
    case clearData
    case signedIn
    case lab
    case branch
    case flow
    case kind
    case splashSeconds
    case shopPath
    case shopFollowUp
    case systemLinks
    case missingDestination
    case labReviewsSeconds

    var flag: String {
        "-\(rawValue)"
    }
}

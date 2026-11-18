//
//  ExampleFlow.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <52625092+JoeOCT91@users.noreply.github.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

// The five flows each branch can launch. They are also the UI test scenarios.
//
// Conformances:
// - `String` raw values, so a launch argument such as `-flow sheet` names a flow, and accessibility
//   identifiers use the same word.
// - `CaseIterable`, so both branches list every flow from this one declaration.
enum ExampleFlow: String, CaseIterable {
    case login
    case tabs
    case detailPush
    case sheet
    case deepLink

    var title: String {
        switch self {
        case .login:
            return "Login"
        case .tabs:
            return "Tabs"
        case .detailPush:
            return "Detail push"
        case .sheet:
            return "Sheet"
        case .deepLink:
            return "Deep link"
        }
    }

    var summary: String {
        switch self {
        case .login:
            return "Sign in, then switch the root to the main tabs"
        case .tabs:
            return "One stack per tab, reselect pops to root"
        case .detailPush:
            return "Push a product, go back with a fallback"
        case .sheet:
            return "A sheet that fits its content and returns a filter"
        case .deepLink:
            return "Open a link straight into a product"
        }
    }

    var symbolName: String {
        switch self {
        case .login:
            return "lock"
        case .tabs:
            return "rectangle.3.group"
        case .detailPush:
            return "arrow.right"
        case .sheet:
            return "rectangle.bottomhalf.filled"
        case .deepLink:
            return "link"
        }
    }
}

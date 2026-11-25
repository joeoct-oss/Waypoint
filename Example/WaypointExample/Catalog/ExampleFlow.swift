//
//  ExampleFlow.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

// The five flows each branch can launch. They are also the UI test scenarios.
//
// Conformances:
// - `String` raw values, so a launch argument such as `-flow sheet` names a flow, and accessibility
//   identifiers use the same word.
// - `Codable` (from the raw values), so a Lab entry can sit in an account route.
// - `CaseIterable`, so both branches list every flow from this one declaration.
package nonisolated enum ExampleFlow: String, CaseIterable, Codable {
    case login
    case tabs
    case detailPush
    case sheet
    case deepLink

    package var title: String {
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

    package var summary: String {
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

    package var symbolName: String {
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

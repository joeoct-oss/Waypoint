//
//  NavigationRules.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import Observation
import WaypointCore

// The app's navigation rules, set once on the main tab router so every stack and presented flow
// inherits them. A `popTo` of a screen that isn't in the stack pops to the stack's
// root (`.popToRoot` for `routeNotInPath`), and a present while a flow is already up replaces it
// (`.replacePresentation` for `alreadyPresenting`). Settings' Navigation rules section shows the
// duplicate push rule, which it can change for testing, and the queued-call limit the app's
// configuration set at launch.
//
// Conformances:
// - `Observable` (from `@Observable`), so Settings redraws when the duplicate push rule changes.
@Observable
package final class NavigationRules {
    private let tabs: TabRouter<MainTab>
    // `var` because `setPushesTwice(_:)` changes it, for Settings to show.
    package private(set) var duplicatePushRule: DuplicatePushRule

    // The most calls the routers queue in one main-actor turn, from the app's configuration.
    package var queueLimit: Int {
        tabs.configuration.maxQueuedChanges
    }

    package init(tabs: TabRouter<MainTab>) {
        self.tabs = tabs
        duplicatePushRule = tabs.duplicatePushRule
        tabs.setFallback(.popToRoot, for: .routeNotInPath)
        tabs.setFallback(.replacePresentation, for: .alreadyPresenting)
    }

    // Settings' toggle: `.allow` lets a second push of the same route go through while the first is
    // still animating, `.skipWhileInFlight` skips it.
    package func setPushesTwice(_ pushesTwice: Bool) {
        let rule = pushesTwice ? DuplicatePushRule.allow : .skipWhileInFlight
        tabs.setDuplicatePushRule(rule)
        duplicatePushRule = rule
    }
}

//
//  PrivacyRoute.swift
//  Waypoint
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import WaypointCore

/// A shared test route for the privacy screen, which belongs to the settings flow.
///
/// Conformances:
/// - `Route`, so it can be pushed, presented and saved in tests.
package struct PrivacyRoute: Route {
    /// The settings flow, so only a settings navigator can push it.
    package typealias Flow = SettingsFlow

    /// Creates the route.
    package init() {
        // No stored properties.
    }
}

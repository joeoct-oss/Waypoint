//
//  PermissiveConfiguration.swift
//  Waypoint
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import WaypointCore

extension NavigationConfiguration {
    /// Every setting at its default, except a permissive registry, for tests about something
    /// other than destinations: they push routes that no renderer registered.
    package static var permissive: NavigationConfiguration {
        NavigationConfiguration(registry: .permissive)
    }
}

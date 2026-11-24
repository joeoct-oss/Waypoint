//
//  WrongFlowPush.swift
//  Waypoint
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

// Must not compile: a shop navigator refuses a settings route (planning #279, decision 0004).
// expected-error: requires the types 'ShopFlow' and 'PrivacyRoute.Flow' (aka 'SettingsFlow')

import WaypointCore

// Conformances:
// - `NavigationFlow`, so routes can name it as their flow.
enum ShopFlow: NavigationFlow { }

// Conformances:
// - `NavigationFlow`, so routes can name it as their flow.
enum SettingsFlow: NavigationFlow { }

// Conformances:
// - `Route`, so it can be pushed, presented and saved.
struct PrivacyRoute: Route {
    typealias Flow = SettingsFlow
}

@MainActor
func showPrivacy(from shop: FlowNavigator<ShopFlow>) {
    shop.push(PrivacyRoute())
}

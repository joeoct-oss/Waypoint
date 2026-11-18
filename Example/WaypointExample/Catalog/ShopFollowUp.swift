//
//  ShopFollowUp.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

// The change made 150 ms into the launch push: go back one screen, go back to the shop, or open a
// link that replaces the stack with the Lunar Clock.
//
// Conformances:
// - `String` raw values, so a launch argument's text can name a case.
enum ShopFollowUp: String {
    case pop
    case popToRoot
    case link
}

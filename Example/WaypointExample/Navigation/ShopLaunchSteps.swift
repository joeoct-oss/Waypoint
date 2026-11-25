//
//  ShopLaunchSteps.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import ExampleCatalog

// Products to push onto the shop at launch in one change, and one more change to make while that
// push still animates. UI tests use them to check a multi-step push and a change that lands
// mid-transition, which iOS 17 drops unless the stack holds it. Plain values, so `nonisolated`,
// like the launch options that hold them.
//
// Conformances:
// - `Sendable`, so `none` can be a static constant of a nonisolated type.
package nonisolated struct ShopLaunchSteps: Sendable {
    package static let none = ShopLaunchSteps(
        productIDs: [],
        followUp: nil
    )

    package let productIDs: [Int]
    package let followUp: ShopFollowUp?
}

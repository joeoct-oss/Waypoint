//
//  ShopLaunchSteps.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

// Products to push onto the shop at launch in one change, and one more change to make while that
// push still animates. UI tests use them to check a multi-step push and a change that lands
// mid-transition, which iOS 17 drops unless the stack holds it.
struct ShopLaunchSteps {
    static let none = ShopLaunchSteps(
        productIDs: [],
        followUp: nil
    )

    let productIDs: [Int]
    let followUp: ShopFollowUp?
}

//
//  SignInReason.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

// Why the accounts sheet opened (AU-02): the action the account gate holds, or `account` when the
// reader tapped Sign in on Account and nothing is held. The sheet's first line says it, and once
// the reader signs in, the "Signed in as" toast says the action carries on.
enum SignInReason {
    case checkout
    case save
    case orders
    case wishlist
    case addresses
    case account

    var line: String {
        switch self {
        case .checkout:
            return "Sign in to check out. Your cart stays as it is."
        case .save:
            return "Sign in to save products to your wish list."
        case .orders:
            return "Sign in to see your orders."
        case .wishlist:
            return "Sign in to see your wish list."
        case .addresses:
            return "Sign in to see your saved addresses."
        case .account:
            return "Sign in to see your orders, addresses and wish list."
        }
    }

    // What the toast says carries on after sign in, or `nil` when nothing was held.
    var resumedAction: String? {
        switch self {
        case .checkout:
            return "Carrying on to checkout"
        case .save:
            return "Saving the product"
        case .orders:
            return "Opening your orders"
        case .wishlist:
            return "Opening your wish list"
        case .addresses:
            return "Opening your addresses"
        case .account:
            return nil
        }
    }
}

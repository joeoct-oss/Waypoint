//
//  MainTab.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <52625092+JoeOCT91@users.noreply.github.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

// The main tabs, in the order the tab bar shows them.
//
// Conformances:
// - `CaseIterable`, so the tab bar lists every tab from this one declaration.
// - `Hashable`, so `TabView` can tag each tab and keep the selection.
enum MainTab: CaseIterable, Hashable {
    case shop
    case search
    case cart
    case account

    var title: String {
        switch self {
        case .shop:
            return "Shop"
        case .search:
            return "Search"
        case .cart:
            return "Cart"
        case .account:
            return "Account"
        }
    }

    var symbolName: String {
        switch self {
        case .shop:
            return "bag"
        case .search:
            return "magnifyingglass"
        case .cart:
            return "cart"
        case .account:
            return "person.crop.circle"
        }
    }
}

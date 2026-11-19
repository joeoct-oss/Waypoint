//
//  MainTab.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

// The main tabs, in the order the tab bar shows them. Each tab's stack is named after its raw value
// in the journey lines and the debug tree: `shop`, `search`, `cart` and `account`.
//
// Conformances:
// - `String` raw value: gives each tab its name in logs, so its stack's flow is `shop`.
// - `NavigationTab`, so the main tab router selects it, and `TabView` can tag each tab with it.
// - `CaseIterable`, so the tab bar and the tab router list every tab from this one declaration.
enum MainTab: String, NavigationTab, CaseIterable {
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

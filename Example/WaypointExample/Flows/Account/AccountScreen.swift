//
//  AccountScreen.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

// A screen the account stack can push: orders, addresses and their form, settings, and the
// Navigation Lab under settings.
//
// Conformances:
// - `Hashable`, so `NavigationStack` can keep screens in its path and tell them apart.
enum AccountScreen: Hashable {
    case orders
    case order(Order)
    case addresses
    case addAddress
    case settings
    case lab
    case labBranch(Branch)
    case labFlow(FlowEntry)
    case labStory(ViewModelStory)

    static let rootTrail = [
        "account",
    ]

    var title: String {
        switch self {
        case .orders:
            return "Orders"
        case .order(let order):
            return "Order \(order.id)"
        case .addresses:
            return "Addresses"
        case .addAddress:
            return "New address"
        case .settings:
            return "Settings"
        case .lab:
            return "Navigation Lab"
        case .labBranch(let branch):
            return branch.title
        case .labFlow(let entry):
            return entry.flow.title
        case .labStory(let story):
            return story.title
        }
    }

    var kind: FlowKind? {
        switch self {
        case .orders, .order, .addresses, .addAddress, .settings, .lab, .labStory:
            return nil
        case .labBranch(let branch):
            return branch.hostKind
        case .labFlow(let entry):
            return entry.kind
        }
    }

    var trail: [String] {
        switch self {
        case .orders:
            return Self.rootTrail + ["orders"]
        case .order(let order):
            return Self.rootTrail + ["orders", "\(order.id)"]
        case .addresses:
            return Self.rootTrail + ["addresses"]
        case .addAddress:
            return Self.rootTrail + ["addresses", "new address"]
        case .settings:
            return Self.rootTrail + ["settings"]
        case .lab:
            return Self.rootTrail + ["settings", "lab"]
        case .labBranch(let branch):
            return Self.labTrail(to: branch)
        case .labFlow(let entry):
            return Self.labTrail(to: entry)
        case .labStory(let story):
            return AccountScreen.lab.trail + [story.code]
        }
    }

    private static func labTrail(to branch: Branch) -> [String] {
        AccountScreen.lab.trail + ["\(branch.rawValue) branch"]
    }

    private static func labTrail(to entry: FlowEntry) -> [String] {
        labTrail(to: entry.branch) + ["\(entry.flow.rawValue) \(entry.kind.rawValue)"]
    }
}

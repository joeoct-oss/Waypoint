//
//  AccountRoute.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import WaypointCore

// A screen the account tab's router can push: orders, addresses and their form, settings, and the
// Navigation Lab under settings.
//
// Conformances:
// - `TrackableScreen`, a `Route` the journey log names by its title.
enum AccountRoute: TrackableScreen {
    case orders
    case order(Order)
    case addresses
    case addAddress
    case settings
    case lab
    case labBranch(Branch)
    case labFlow(FlowEntry)
    case labStory(ViewModelStory)
    case labTool(LabTool)

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
        case .labTool(let tool):
            return tool.title
        }
    }

    var screenDisplayName: String? {
        title
    }

    var kind: FlowKind? {
        switch self {
        case .orders, .order, .addresses, .addAddress, .settings, .lab, .labStory, .labTool:
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
            return AccountRoute.lab.trail + [story.code]
        case .labTool(let tool):
            return AccountRoute.lab.trail + [tool.title.lowercased()]
        }
    }

    private static func labTrail(to branch: Branch) -> [String] {
        AccountRoute.lab.trail + ["\(branch.rawValue) branch"]
    }

    private static func labTrail(to entry: FlowEntry) -> [String] {
        labTrail(to: entry.branch) + ["\(entry.flow.rawValue) \(entry.kind.rawValue)"]
    }
}

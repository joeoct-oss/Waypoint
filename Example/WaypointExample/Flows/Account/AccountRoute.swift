//
//  AccountRoute.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import ExampleCatalog
import ExampleNavigation
import ExampleStore
import WaypointCore

// A screen the account tab's router can push: orders, the wish list, addresses and their form,
// settings, and the Navigation Lab under settings.
//
// Conformances:
// - `TrackableScreen`, a `Route` the journey log names by its title.
enum AccountRoute: TrackableScreen {
    case orders
    case order(Order)
    case wishlist
    case addresses
    case addAddress
    case settings
    case lab
    case labBranch(Branch)
    case labFlow(FlowEntry)
    case labStory(ViewModelStory)
    case labTool(LabTool)

    var title: String {
        switch self {
        case .orders:
            return "Orders"
        case .order(let order):
            return "Order \(order.id)"
        case .wishlist:
            return "Wish list"
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
        case .orders, .order, .wishlist, .addresses, .addAddress, .settings, .lab, .labStory, .labTool:
            return nil
        case .labBranch(let branch):
            return branch.hostKind
        case .labFlow(let entry):
            return entry.kind
        }
    }
}

extension AccountRoute {
    // The path a launch into the Lab starts on: Settings and the Lab, then the launch's branch,
    // then its entry when that entry shows a placeholder. Empty for any other launch.
    static func launchPath(for launch: LaunchOptions) -> [AccountRoute] {
        guard launch.opensLab else {
            return []
        }
        let lab: [AccountRoute] = [.settings, .lab]
        guard let branch = launch.branch else {
            return lab
        }
        guard let entry = launch.entry, !entry.isRunnable else {
            return lab + [.labBranch(branch)]
        }
        return lab + [.labBranch(branch), .labFlow(entry)]
    }
}

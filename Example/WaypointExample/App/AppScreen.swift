//
//  AppScreen.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <52625092+JoeOCT91@users.noreply.github.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

// A screen the app coordinator can push above Home.
//
// Conformances:
// - `Hashable`, so `NavigationStack` can keep screens in its path and tell them apart.
enum AppScreen: Hashable {
    case branch(Branch)
    case flow(FlowEntry)

    static let homeTitle = "Example"
    static let homeTrail = [
        "home",
    ]

    var title: String {
        switch self {
        case .branch(let branch):
            return branch.title
        case .flow(let entry):
            return entry.flow.title
        }
    }

    var kind: FlowKind {
        switch self {
        case .branch(let branch):
            return branch.hostKind
        case .flow(let entry):
            return entry.kind
        }
    }

    var trail: [String] {
        switch self {
        case .branch(let branch):
            return Self.trail(to: branch)
        case .flow(let entry):
            return Self.trail(to: entry)
        }
    }

    private static func trail(to branch: Branch) -> [String] {
        let step = "\(branch.rawValue) branch"
        return homeTrail + [step]
    }

    private static func trail(to entry: FlowEntry) -> [String] {
        let step = "\(entry.flow.rawValue) \(entry.kind.rawValue)"
        return trail(to: entry.branch) + [step]
    }
}

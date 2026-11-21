//
//  FlowEntry.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

// One of the twenty entry points: a flow of one kind, launched from one branch. Only `detailPush`
// and `tabs` run for real so far; the others open a placeholder.
//
// Conformances:
// - `Hashable`, so the app coordinator can keep an entry in its navigation path.
// - `Codable`, so an entry can sit in an account route, which Waypoint can save and restore.
struct FlowEntry: Hashable, Codable {
    // The entries that run for real so far, both of the SwiftUI kind from the SwiftUI branch:
    // Detail push, and Tabs. The others open a placeholder until the APIs they need are built.
    static let detailPush = FlowEntry(
        branch: .swiftUI,
        flow: .detailPush,
        kind: .swiftUI
    )
    static let tabs = FlowEntry(
        branch: .swiftUI,
        flow: .tabs,
        kind: .swiftUI
    )

    static var all: [FlowEntry] {
        Branch.allCases.flatMap(entries(in:))
    }

    let branch: Branch
    let flow: ExampleFlow
    let kind: FlowKind

    var isRunnable: Bool {
        demo != nil
    }

    // The Lab demo that runs the entry for real, or `nil` for a placeholder.
    var demo: LabDemo? {
        switch self {
        case Self.detailPush:
            return .detailPush
        case Self.tabs:
            return .tabs
        default:
            return nil
        }
    }

    static func entries(in branch: Branch) -> [FlowEntry] {
        ExampleFlow.allCases.flatMap { flow in
            FlowKind.allCases.map { FlowEntry(branch: branch, flow: flow, kind: $0) }
        }
    }
}

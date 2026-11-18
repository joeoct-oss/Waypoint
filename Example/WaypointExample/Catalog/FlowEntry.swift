//
//  FlowEntry.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

// One of the twenty entry points: a flow of one kind, launched from one branch.
//
// Conformances:
// - `Hashable`, so the app coordinator can keep an entry in its navigation path.
struct FlowEntry: Hashable {
    static var all: [FlowEntry] {
        Branch.allCases.flatMap(entries(in:))
    }

    let branch: Branch
    let flow: ExampleFlow
    let kind: FlowKind

    static func entries(in branch: Branch) -> [FlowEntry] {
        ExampleFlow.allCases.flatMap { flow in
            FlowKind.allCases.map { FlowEntry(branch: branch, flow: flow, kind: $0) }
        }
    }
}

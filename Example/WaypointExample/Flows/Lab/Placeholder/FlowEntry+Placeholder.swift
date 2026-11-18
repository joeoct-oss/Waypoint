//
//  FlowEntry+Placeholder.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

// The text a placeholder screen shows until its flow is built.
extension FlowEntry {
    var placeholderLine: String {
        "placeholder branch=\(branch.rawValue) flow=\(flow.rawValue) kind=\(kind.rawValue)"
    }

    var placeholderNote: String {
        "This \(kind.title) flow is a placeholder. The real \(flow.title.lowercased()) flow replaces it."
    }
}

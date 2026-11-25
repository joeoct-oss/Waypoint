//
//  FlowEntry+LabDemo.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import ExampleCatalog

// Kept out of `Catalog`, which the UI tests compile too, because `LabDemo` is the app's alone.
extension FlowEntry {
    // The Lab demo that runs the entry for real, or `nil` for a placeholder.
    package var demo: LabDemo? {
        switch self {
        case Self.detailPush:
            return .detailPush
        case Self.tabs:
            return .tabs
        case Self.sheet:
            return .sheet
        default:
            return nil
        }
    }
}

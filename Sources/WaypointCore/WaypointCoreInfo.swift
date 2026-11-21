//
//  WaypointCoreInfo.swift
//  Waypoint
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

// WaypointCore is the UI-agnostic navigation state engine behind Waypoint.
//
// It imports only Foundation and Observation, so it builds and runs its tests on Linux.
// `Waypoint`, which holds the SwiftUI and UIKit renderers, builds on top of it.

import Foundation
import Observation

/// Build information for the core module. A placeholder until the public API lands.
enum WaypointCoreInfo {
    /// The package version this module was built from.
    static let version = "0.0.0"
}

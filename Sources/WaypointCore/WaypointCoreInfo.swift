//
//  WaypointCoreInfo.swift
//  Waypoint
//
//  Created by Yousef Mohamed <52625092+JoeOCT91@users.noreply.github.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

// WaypointCore is the UI-agnostic navigation state engine behind Waypoint.
//
// It imports only Foundation and Observation, so it builds and runs its tests on Linux.
// The SwiftUI renderer (`Waypoint`) and the UIKit renderer (`WaypointUIKit`) build on top of it.

import Foundation
import Observation

/// Build information for the core module. A placeholder until the public API lands.
enum WaypointCoreInfo {
    /// The package version this module was built from.
    static let version = "0.0.0"
}

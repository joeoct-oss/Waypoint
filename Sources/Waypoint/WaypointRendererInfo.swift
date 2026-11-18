//
//  WaypointRendererInfo.swift
//  Waypoint
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

// Waypoint is the SwiftUI renderer for WaypointCore.
//
// The whole file is guarded so the module compiles empty on platforms without SwiftUI, such as Linux.

#if canImport(SwiftUI)
    import SwiftUI
    import WaypointCore

    /// Placeholder until the SwiftUI renderer lands.
    enum WaypointRendererInfo {
        /// The name of the renderer.
        static let name = "SwiftUI"
    }
#endif

//
//  WaypointUIKitRendererInfo.swift
//  Waypoint
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

// WaypointUIKit is the UIKit renderer for WaypointCore.
//
// The whole file is guarded so the module compiles empty on platforms without UIKit, such as Linux
// and macOS.

#if canImport(UIKit)
    import UIKit
    import WaypointCore

    /// Placeholder until the UIKit renderer lands.
    enum WaypointUIKitRendererInfo {
        /// The name of the renderer.
        static let name = "UIKit"
    }
#endif

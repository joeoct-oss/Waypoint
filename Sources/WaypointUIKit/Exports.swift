//
//  Exports.swift
//  Waypoint
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

#if canImport(UIKit)
    // Apps that import WaypointUIKit get `OSLogHandler` and `LogConfiguration.osLog()` with no
    // extra import, because the unified log target is not a product of its own (decision 0008).
    // The UIKit renderer's entry points (#14) call `DefaultLogging.install(on:)` before they draw.
    @_exported import WaypointOSLog
#endif

//
//  Exports.swift
//  Waypoint
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

// Apps import only `Waypoint`, the one UI product (decision 0017), and get the core's routes,
// routers and outcomes with it. Code that draws nothing may import `WaypointCore` alone, so it
// stays free of UI frameworks (planning #425).
@_exported import WaypointCore

#if canImport(os)
    // Apps that import Waypoint get `OSLogHandler` and `LogConfiguration.osLog()` with no extra
    // import, because the unified log target is not a product of its own (decision 0008).
    @_exported import WaypointOSLog
#endif

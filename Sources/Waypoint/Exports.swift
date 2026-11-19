//
//  Exports.swift
//  Waypoint
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

#if canImport(os)
    // Apps that import Waypoint get `OSLogHandler` and `LogConfiguration.osLog()` with no extra
    // import, because the unified log target is not a product of its own (decision 0008).
    @_exported import WaypointOSLog
#endif

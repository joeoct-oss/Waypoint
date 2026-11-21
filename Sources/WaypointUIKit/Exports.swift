//
//  Exports.swift
//  Waypoint
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

#if canImport(UIKit)
    // Until this placeholder product is removed, apps that import WaypointUIKit get
    // `OSLogHandler` and `LogConfiguration.osLog()` with no extra import, because the unified log
    // target is not a product of its own. The UIKit renderers are designed to
    // go into `Waypoint`.
    @_exported import WaypointOSLog
#endif

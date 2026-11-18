//
//  BuildConfiguration.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

// The build configuration this code was compiled in. The app shows it with a navigation issue, and
// the UI tests, which compile this file too, check the app was built the same way they were.
enum BuildConfiguration {
    static var name: String {
        #if DEBUG
            return "debug"
        #else
            return "release"
        #endif
    }
}

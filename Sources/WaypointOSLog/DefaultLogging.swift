//
//  DefaultLogging.swift
//  Waypoint
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

#if canImport(os)
    import WaypointCore

    /// How the renderers make the unified log the default: before a renderer draws a tree, it
    /// installs one shared ``OSLogHandler`` when the app gave no handler. A handler the app chose,
    /// `.disabled` included, is kept.
    package enum DefaultLogging {
        /// The handler every tree without one of its own writes to, so all of them share one
        /// logger per category.
        package static let handler = OSLogHandler()

        /// Installs ``handler`` on the tree of `router`, unless the app chose a handler.
        @MainActor
        package static func install(on router: StackRouter) {
            router.installDefaultLogHandler {
                handler
            }
        }

        /// Installs ``handler`` on the tree of `router`, unless the app chose a handler.
        @MainActor
        package static func install<Tab: NavigationTab>(on router: TabRouter<Tab>) {
            router.installDefaultLogHandler {
                handler
            }
        }
    }
#endif

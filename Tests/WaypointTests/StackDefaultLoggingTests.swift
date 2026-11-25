//
//  StackDefaultLoggingTests.swift
//  Waypoint
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

// Compiles empty where SwiftUI is missing, like the stack it tests. Run on a Mac.

#if canImport(SwiftUI)
    import SwiftUI
    import Testing
    import WaypointTestSupport

    @testable import Waypoint
    @testable import WaypointCore

    /// The SwiftUI stack makes the unified log the default (planning #328).
    @Suite("Stack default logging")
    @MainActor
    struct StackDefaultLoggingTests {
        @Test("A stack logs to the unified log at notice when the app gave no handler")
        func stackInstallsTheUnifiedLogWhenTheAppGaveNoHandler() {
            let router = StackRouter(configuration: .permissive)

            _ = StackHost(router: router, root: EmptyView())

            #expect(router.configuration.logging.handler is OSLogHandler)
            #expect(router.configuration.logging.minimumLevel == .notice)
        }

        @Test("A stack keeps the app's own log settings")
        func stackKeepsTheAppsHandler() {
            let configuration = NavigationConfiguration(logging: .disabled, registry: .permissive)
            let disabled = StackRouter(configuration: configuration)

            _ = StackHost(router: disabled, root: EmptyView())

            #expect(disabled.configuration.logging.handler is DisabledLogHandler)
        }
    }
#endif

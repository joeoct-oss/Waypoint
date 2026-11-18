//
//  StackNavigation.swift
//  Waypoint
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

#if canImport(SwiftUI)
    import SwiftUI
    import WaypointCore

    /// The navigator of the nearest ``WaypointStack`` above the view.
    ///
    /// ```swift
    /// struct HelpView: View {
    ///     @StackNavigation private var navigation
    ///
    ///     var body: some View {
    ///         Button("Contact us") { navigation.push(ContactRoute()) }
    ///     }
    /// }
    /// ```
    ///
    /// It holds no navigation state: it reads the router from the environment and gives its
    /// `StackNavigator`. It is optional; outputs, injected navigators and
    /// `@Environment(StackRouter.self)` work too. With no stack above the view, every call fails
    /// with `noRouterInScope`, naming this declaration's file and line, and nothing crashes.
    ///
    /// Conformances:
    /// - `DynamicProperty`, so SwiftUI updates the view when the router changes.
    @propertyWrapper
    public struct StackNavigation: DynamicProperty {
        /// The router of the nearest stack, or `nil` outside one.
        @Environment(\.waypointStackRouter) private var router

        /// Where the wrapper is declared, for issues.
        private let site: WrapperSite

        /// The nearest stack's navigator.
        @MainActor
        public var wrappedValue: StackNavigator {
            NavigatorLookup.stack(router, site: site, report: NavigationIssueLog.report)
        }

        /// Reads the nearest stack's navigator.
        ///
        /// - Parameters:
        ///   - file: The file of the declaration, where a missing stack is reported. Leave the
        ///     default.
        ///   - line: The line of the declaration, where a missing stack is reported. Leave the
        ///     default.
        public init(file: StaticString = #fileID, line: UInt = #line) {
            self.site = WrapperSite(file: file, line: line)
        }
    }
#endif

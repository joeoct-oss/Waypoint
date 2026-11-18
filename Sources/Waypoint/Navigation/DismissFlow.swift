//
//  DismissFlow.swift
//  Waypoint
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

#if canImport(SwiftUI)
    import SwiftUI
    import WaypointCore

    /// Dismisses the flow the view is in, as a ``DismissFlowAction`` you call.
    ///
    /// ```swift
    /// struct SettingsView: View {
    ///     @DismissFlow private var dismissFlow
    ///
    ///     var body: some View {
    ///         Button("Close") { dismissFlow() }
    ///     }
    /// }
    /// ```
    ///
    /// It dismisses the whole presented flow, however deep the view is in it, unlike SwiftUI's
    /// `dismiss`, which pops one screen. It is optional, like every navigation wrapper. With no
    /// stack above the view, a call fails with `noRouterInScope`, naming this declaration's file
    /// and line, and nothing crashes.
    ///
    /// Conformances:
    /// - `DynamicProperty`, so SwiftUI updates the view when the router changes.
    @propertyWrapper
    public struct DismissFlow: DynamicProperty {
        /// The router of the nearest stack, or `nil` outside one.
        @Environment(\.waypointStackRouter) private var router

        /// Where the wrapper is declared, for issues.
        private let site: WrapperSite

        /// The action that dismisses the view's flow.
        @MainActor
        public var wrappedValue: DismissFlowAction {
            NavigatorLookup.dismissFlow(router, site: site, report: NavigationIssueLog.report)
        }

        /// Reads the action that dismisses the view's flow.
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

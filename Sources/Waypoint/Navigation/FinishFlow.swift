//
//  FinishFlow.swift
//  Waypoint
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

#if canImport(SwiftUI)
    import SwiftUI
    import WaypointCore

    /// Ends the child flow the view is in with a value, as a ``FinishFlowAction`` you call.
    ///
    /// ```swift
    /// struct ReviewView: View {
    ///     @FinishFlow(ReviewCoordinator.self) private var finishFlow
    ///     let review: Review
    ///
    ///     var body: some View {
    ///         Button("Post") { finishFlow(review) }
    ///     }
    /// }
    /// ```
    ///
    /// The action takes only `Flow.Output`, so a view can't finish its flow with a value of the
    /// wrong type. The parent gets `.finished(value)`, as when the coordinator calls
    /// `finish(with:)`. It is optional, like every navigation wrapper: a coordinator can still
    /// finish the flow itself. Outside a flow of `Flow`, a call fails with `noRouterInScope`,
    /// naming this declaration's file and line, and nothing crashes.
    ///
    /// Conformances:
    /// - `DynamicProperty`, so SwiftUI updates the view when the router changes.
    /// - `Flow: FlowCoordinator`, because only a flow that ends with a value can be finished.
    @propertyWrapper
    public struct FinishFlow<Flow: FlowCoordinator>: DynamicProperty {
        /// The router of the nearest stack, or `nil` outside one.
        @Environment(\.waypointStackRouter) private var router

        /// Where the wrapper is declared, for issues.
        private let site: WrapperSite

        /// The action that finishes the view's flow.
        @MainActor
        public var wrappedValue: FinishFlowAction<Flow.Output> {
            NavigatorLookup.finishFlow(Flow.self, router, site: site, report: NavigationIssueLog.report)
        }

        /// Reads the action that finishes the flow of `flow` the view is in.
        ///
        /// - Parameters:
        ///   - flow: The coordinator type of the flow to finish.
        ///   - file: The file of the declaration, where a missing flow is reported. Leave the
        ///     default.
        ///   - line: The line of the declaration, where a missing flow is reported. Leave the
        ///     default.
        public init(_ flow: Flow.Type, file: StaticString = #fileID, line: UInt = #line) {
            self.site = WrapperSite(file: file, line: line)
        }
    }
#endif

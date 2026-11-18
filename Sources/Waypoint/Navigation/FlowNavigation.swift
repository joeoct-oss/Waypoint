//
//  FlowNavigation.swift
//  Waypoint
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

#if canImport(SwiftUI)
    import SwiftUI
    import WaypointCore

    /// The navigator of the nearest stack of `Flow` above the view, which only takes that flow's
    /// routes.
    ///
    /// ```swift
    /// struct ProductView: View {
    ///     @FlowNavigation(ShopFlow.self) private var shop
    ///
    ///     var body: some View {
    ///         Button("Add to cart") { shop.push(CartRoute()) }
    ///     }
    /// }
    /// ```
    ///
    /// A stack belongs to a flow when it is made with `WaypointStack(flow:)`, or when its router
    /// was declared with `declareFlow(_:)`. The wrapper finds the nearest one, even from a screen
    /// presented inside it. Pushing another flow's route doesn't compile. With no stack of
    /// `Flow` above the view, every call fails with `noRouterInScope`, naming this declaration's
    /// file and line and the fix, and nothing crashes.
    ///
    /// Conformances:
    /// - `DynamicProperty`, so SwiftUI updates the view when the router changes.
    /// - `Flow: NavigationFlow`: the flow whose routes are accepted.
    @propertyWrapper
    public struct FlowNavigation<Flow: NavigationFlow>: DynamicProperty {
        /// The nearest stack of each declared flow.
        @Environment(\.waypointFlowRouters) private var routers

        /// Where the wrapper is declared, for issues.
        private let site: WrapperSite

        /// The navigator of the nearest stack of `Flow`.
        @MainActor
        public var wrappedValue: FlowNavigator<Flow> {
            NavigatorLookup.flow(Flow.self, in: routers, site: site, report: NavigationIssueLog.report)
        }

        /// Reads the navigator of the nearest stack of `flow`.
        ///
        /// - Parameters:
        ///   - flow: The flow whose stack to find.
        ///   - file: The file of the declaration, where a missing stack is reported. Leave the
        ///     default.
        ///   - line: The line of the declaration, where a missing stack is reported. Leave the
        ///     default.
        public init(_ flow: Flow.Type, file: StaticString = #fileID, line: UInt = #line) {
            self.site = WrapperSite(file: file, line: line)
        }
    }
#endif

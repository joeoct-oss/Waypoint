//
//  StackRouter+Navigators.swift
//  Waypoint
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

extension StackRouter {
    /// A navigator for the screen on top of this stack, taking any route. Hand it to that
    /// screen's view model instead of the router.
    ///
    /// The navigator does nothing once that screen is popped or the flow is gone. Taken while
    /// the path is empty, it belongs to the root screen and lives as long as the flow.
    public var navigator: StackNavigator {
        StackNavigator(router: self, screen: topScreen)
    }

    /// A navigator for the top-most screen showing `route`, or for the root screen when none
    /// does. Renderers give one to each destination closure, so a screen's view model can't
    /// navigate once the screen is popped.
    package func navigator(forScreenShowing route: AnyRoute) -> StackNavigator {
        StackNavigator(router: self, screen: screen(showing: route))
    }

    /// A navigator for the stack's root screen, which lives as long as the flow. The property
    /// wrappers use it, since they are read again on every draw.
    package var rootScreenNavigator: StackNavigator {
        StackNavigator(router: self, screen: .root)
    }

    /// A navigator for the screen on top of this stack that takes only the routes of `flow`.
    ///
    /// ```swift
    /// let model = ProductModel(navigation: router.navigator(for: ShopFlow.self))
    /// ```
    ///
    /// If this stack was declared for another flow with ``declareFlow(_:)``, the navigator still
    /// works and a `flowMismatch` issue is reported at this call. A stack declared for no flow
    /// gives a navigator for any flow.
    ///
    /// - Parameters:
    ///   - flow: The flow whose routes the navigator takes.
    ///   - file: The file of the call, where a mismatch is reported. Leave the default.
    ///   - line: The line of the call, where a mismatch is reported. Leave the default.
    public func navigator<Flow: NavigationFlow>(
        for flow: Flow.Type,
        file: StaticString = #fileID,
        line: UInt = #line
    ) -> FlowNavigator<Flow> {
        checkFlow(flow, file: file, line: line)
        return FlowNavigator(unscoped: navigator)
    }

    /// A navigator for the stack's root screen that takes only the routes of `flow`, for
    /// `@FlowNavigation`. Reports a mismatch like ``navigator(for:file:line:)``.
    package func rootScreenNavigator<Flow: NavigationFlow>(
        for flow: Flow.Type,
        file: StaticString = #fileID,
        line: UInt = #line
    ) -> FlowNavigator<Flow> {
        checkFlow(flow, file: file, line: line)
        return FlowNavigator(unscoped: rootScreenNavigator)
    }

    /// Reports `flowMismatch` when this stack was declared for another flow than `flow`.
    func checkFlow<Flow: NavigationFlow>(_ flow: Flow.Type, file: StaticString, line: UInt) {
        if let declared = declaredFlow, declared != flow {
            reportFlowMismatch(asked: flow, declared: declared, file: file, line: line)
        }
    }

    /// Reports a scoped navigator asked of a stack declared for another flow.
    private func reportFlowMismatch(
        asked: any NavigationFlow.Type,
        declared: any NavigationFlow.Type,
        file: StaticString,
        line: UInt
    ) {
        let message =
            "navigator(for: \(asked).self) was asked of \(flowID), a stack declared for "
            + "\(declared). The navigator works, but check that the screen is in the flow you meant."
        let issue = NavigationIssue(kind: .flowMismatch, flow: flowID, message: message, file: file, line: line)
        tree.report(issue, level: .error)
    }
}

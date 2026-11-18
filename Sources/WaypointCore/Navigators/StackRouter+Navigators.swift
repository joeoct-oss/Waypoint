//
//  StackRouter+Navigators.swift
//  Waypoint
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

extension StackRouter {
    /// A navigator for this stack that takes any route. Hand it to a view model instead of the
    /// router.
    public var navigator: StackNavigator {
        StackNavigator(router: self)
    }

    /// A navigator for this stack that takes only the routes of `flow`.
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
        if let declared = declaredFlow, declared != flow {
            reportFlowMismatch(asked: flow, declared: declared, file: file, line: line)
        }
        return FlowNavigator(unscoped: navigator)
    }

    /// Reports a scoped navigator asked of a stack declared for another flow.
    private func reportFlowMismatch(
        asked: any NavigationFlow.Type,
        declared: any NavigationFlow.Type,
        file: StaticString,
        line: UInt
    ) {
        let message = "navigator(for: \(asked).self) was asked of \(flowID), a stack declared for "
            + "\(declared). The navigator works, but check that the screen is in the flow you meant."
        let issue = NavigationIssue(kind: .flowMismatch, flow: flowID, message: message, file: file, line: line)
        tree.report(issue, level: .error)
    }
}

//
//  FlowNavigator.swift
//  Waypoint
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

/// Navigates one stack with the routes of one flow only, checked by the compiler.
///
/// A route names its flow with `typealias Flow = ShopFlow`. A shop navigator then pushes shop
/// routes, and pushing another flow's route doesn't compile:
///
/// ```swift
/// let shop = router.navigator(for: ShopFlow.self)
/// shop.push(CartRoute())       // CartRoute.Flow is ShopFlow
/// shop.push(PrivacyRoute())    // error: PrivacyRoute belongs to SettingsFlow
/// shop.unscoped.push(HelpRoute())
/// ```
///
/// ``unscoped`` is the escape hatch for a screen every flow shares, visible in code review on
/// purpose. Presenting takes any route, because a presented route starts a flow of its own.
/// Like ``StackNavigator``, it holds its router weakly and does nothing once its flow is gone.
///
/// Conformances:
/// - `Flow: NavigationFlow`: the flow whose routes are accepted.
@MainActor
public struct FlowNavigator<Flow: NavigationFlow> {
    /// The same stack, with any route.
    public let unscoped: StackNavigator

    /// Whether this navigator's flow is still in the tree. When it isn't, every call returns
    /// `.ignored`.
    public var isActive: Bool {
        unscoped.isActive
    }

    /// A scoped navigator over `unscoped`.
    init(unscoped: StackNavigator) {
        self.unscoped = unscoped
    }

    /// A navigator made where no stack of `Flow` is in scope. Every call fails with
    /// `noRouterInScope` and `message`, and calls `report` with the issue.
    package init(missing message: String, report: @escaping @MainActor (NavigationIssue) -> Void) {
        self.unscoped = StackNavigator(missing: message, report: report)
    }

    /// Pushes a route of this flow. See ``StackRouter/push(_:else:file:line:)``.
    @discardableResult
    public func push<R: Route>(
        _ route: R,
        else fallback: NavigationFallback? = nil,
        file: StaticString = #fileID,
        line: UInt = #line
    ) -> NavigationOutcome where R.Flow == Flow {
        unscoped.push(route, else: fallback, file: file, line: line)
    }

    /// Pops back to the last screen showing `route`, a route of this flow. See
    /// ``StackRouter/popTo(_:else:file:line:)``.
    @discardableResult
    public func popTo<R: Route>(
        _ route: R,
        else fallback: NavigationFallback? = nil,
        file: StaticString = #fileID,
        line: UInt = #line
    ) -> NavigationOutcome where R.Flow == Flow {
        unscoped.popTo(route, else: fallback, file: file, line: line)
    }

    /// Pops `count` routes. See ``StackRouter/pop(count:else:file:line:)``.
    @discardableResult
    public func pop(
        count: Int = 1,
        else fallback: NavigationFallback? = nil,
        file: StaticString = #fileID,
        line: UInt = #line
    ) -> NavigationOutcome {
        unscoped.pop(count: count, else: fallback, file: file, line: line)
    }

    /// Pops back to the stack's root screen. See ``StackRouter/popToRoot(else:file:line:)``.
    @discardableResult
    public func popToRoot(
        else fallback: NavigationFallback? = nil,
        file: StaticString = #fileID,
        line: UInt = #line
    ) -> NavigationOutcome {
        unscoped.popToRoot(else: fallback, file: file, line: line)
    }

    /// Presents `route` over this flow, as the root screen of a new child flow. Any route, since
    /// the presented flow is another flow. See ``StackRouter/present(_:style:else:file:line:)``.
    @discardableResult
    public func present<R: Route>(
        _ route: R,
        style: PresentationStyle = .sheet,
        else fallback: NavigationFallback? = nil,
        file: StaticString = #fileID,
        line: UInt = #line
    ) -> NavigationOutcome {
        unscoped.present(route, style: style, else: fallback, file: file, line: line)
    }

    /// Dismisses the flow this navigator belongs to, when it was presented. See
    /// ``StackRouter/dismissFlow(else:file:line:)``.
    @discardableResult
    public func dismissFlow(
        else fallback: NavigationFallback? = nil,
        file: StaticString = #fileID,
        line: UInt = #line
    ) -> NavigationOutcome {
        unscoped.dismissFlow(else: fallback, file: file, line: line)
    }
}

//
//  StackNavigator.swift
//  Waypoint
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

/// Navigates one stack with any route, and owns nothing.
///
/// Give a view model a navigator instead of the router. The model imports only `WaypointCore`
/// and is tested with a real router, on Linux too:
///
/// ```swift
/// @Observable @MainActor
/// final class ProductListModel {
///     private let navigation: StackNavigator
///
///     init(navigation: StackNavigator) {
///         self.navigation = navigation
///     }
///
///     func select(productID: Int) {
///         navigation.push(ProductRoute(id: productID))
///     }
/// }
///
/// let model = ProductListModel(navigation: router.navigator)
/// ```
///
/// Every call is the router's own method, so outcomes, fallbacks and logs are the same.
///
/// A navigator belongs to one screen: the screen on top of the stack when it was taken, or the
/// screen a destination closure draws. It holds its router weakly. Once that screen is popped,
/// or its flow is gone (dismissed, removed or released), every call does nothing, returns
/// `.ignored` and logs `staleNavigator`, and ``isActive`` is `false`. A screen still on the stack
/// keeps a live navigator, however many screens are pushed above it, and the root screen's
/// navigator lives as long as its flow. See <doc:Concurrency>.
@MainActor
public struct StackNavigator {
    /// The router this navigator drives, or `nil` once it is released or when none was in scope.
    private weak let router: StackRouter?

    /// The router's tree, held weakly, so a call after the router is released is still logged.
    private weak let tree: NavigationTreeContext?

    /// The flow this navigator was made for, or `nil` when no router was in scope.
    private let flowID: FlowID?

    /// The screen this navigator was made for.
    private let screen: ScreenBinding

    /// Why no router was in scope and who hears it, or `nil` for a navigator made by a router.
    private let missing: MissingRouter?

    /// Whether this navigator's screen is still on its stack and its flow still in the tree.
    /// When it isn't, every call returns `.ignored`.
    public var isActive: Bool {
        guard let router else {
            return false
        }
        return router.isActive && router.isOnStack(screen)
    }

    /// A navigator for `screen` of `router`.
    init(router: StackRouter, screen: ScreenBinding) {
        self.router = router
        self.tree = router.tree
        self.flowID = router.flowID
        self.screen = screen
        self.missing = nil
    }

    /// A navigator made where no router is in scope, such as a property wrapper with no stack
    /// above its view. Every call fails with `noRouterInScope` and `message`, and calls `report`
    /// with the issue, so renderers can make it loud in development. It never crashes.
    package init(missing message: String, report: @escaping @MainActor (NavigationIssue) -> Void) {
        self.router = nil
        self.tree = nil
        self.flowID = nil
        self.screen = .root
        self.missing = MissingRouter(message: message, report: report)
    }

    /// Pushes one route. See ``StackRouter/push(_:trigger:else:file:line:)``.
    @discardableResult
    public func push<R: Route>(
        _ route: R,
        trigger: String? = nil,
        else fallback: NavigationFallback? = nil,
        file: StaticString = #fileID,
        line: UInt = #line
    ) -> NavigationOutcome {
        guard let router, router.isOnStack(screen) else {
            return unavailable(file: file, line: line)
        }
        return router.calling(from: screen) {
            router.push(route, trigger: trigger, else: fallback, file: file, line: line)
        }
    }

    /// Pops `count` routes. See ``StackRouter/pop(count:else:file:line:)``.
    @discardableResult
    public func pop(
        count: Int = 1,
        else fallback: NavigationFallback? = nil,
        file: StaticString = #fileID,
        line: UInt = #line
    ) -> NavigationOutcome {
        guard let router, router.isOnStack(screen) else {
            return unavailable(file: file, line: line)
        }
        return router.calling(from: screen) {
            router.pop(count: count, else: fallback, file: file, line: line)
        }
    }

    /// Pops back to the last screen showing `route`. See ``StackRouter/popTo(_:else:file:line:)``.
    @discardableResult
    public func popTo<R: Route>(
        _ route: R,
        else fallback: NavigationFallback? = nil,
        file: StaticString = #fileID,
        line: UInt = #line
    ) -> NavigationOutcome {
        guard let router, router.isOnStack(screen) else {
            return unavailable(file: file, line: line)
        }
        return router.calling(from: screen) {
            router.popTo(route, else: fallback, file: file, line: line)
        }
    }

    /// Pops back to the stack's root screen. See ``StackRouter/popToRoot(else:file:line:)``.
    @discardableResult
    public func popToRoot(
        else fallback: NavigationFallback? = nil,
        file: StaticString = #fileID,
        line: UInt = #line
    ) -> NavigationOutcome {
        guard let router, router.isOnStack(screen) else {
            return unavailable(file: file, line: line)
        }
        return router.calling(from: screen) {
            router.popToRoot(else: fallback, file: file, line: line)
        }
    }

    /// Presents `route` over this flow, as the root screen of a new child flow. See
    /// ``StackRouter/present(_:style:trigger:else:file:line:)``.
    @discardableResult
    public func present<R: Route>(
        _ route: R,
        style: PresentationStyle = .sheet,
        trigger: String? = nil,
        else fallback: NavigationFallback? = nil,
        file: StaticString = #fileID,
        line: UInt = #line
    ) -> NavigationOutcome {
        guard let router, router.isOnStack(screen) else {
            return unavailable(file: file, line: line)
        }
        return router.calling(from: screen) {
            router.present(route, style: style, trigger: trigger, else: fallback, file: file, line: line)
        }
    }

    /// Dismisses the flow this navigator belongs to, when it was presented. See
    /// ``StackRouter/dismissFlow(else:file:line:)``.
    @discardableResult
    public func dismissFlow(
        else fallback: NavigationFallback? = nil,
        file: StaticString = #fileID,
        line: UInt = #line
    ) -> NavigationOutcome {
        guard let router, router.isOnStack(screen) else {
            return unavailable(file: file, line: line)
        }
        return router.calling(from: screen) {
            router.dismissFlow(else: fallback, file: file, line: line)
        }
    }

    /// The same stack, taking only the routes of `flow`, such as for a view model that gets this
    /// navigator from a destination closure.
    ///
    /// ```swift
    /// .destination(ProductRoute.self) { route, navigation in
    ///     let shop = navigation.scoped(to: ShopFlow.self)
    ///     ProductView(model: ProductModel(id: route.id, navigation: shop))
    /// }
    /// ```
    ///
    /// Like ``StackRouter/navigator(for:file:line:)``, it reports `flowMismatch` at this call when
    /// the stack was declared for another flow, and the navigator still works.
    public func scoped<Flow: NavigationFlow>(
        to flow: Flow.Type,
        file: StaticString = #fileID,
        line: UInt = #line
    ) -> FlowNavigator<Flow> {
        router?.checkFlow(flow, file: file, line: line)
        return FlowNavigator(unscoped: self)
    }

    /// What a call does with no router: fails when none was in scope, and is ignored when the
    /// router was released or the screen popped.
    private func unavailable(file: StaticString, line: UInt) -> NavigationOutcome {
        if let missing {
            return missing.fail(file: file, line: line)
        }
        guard let tree, let flowID else {
            return .ignored
        }
        return tree.ignoreStale(flowID, file: file, line: line)
    }
}

/// Why a navigator has no router, and who hears about each call.
@MainActor
private struct MissingRouter {
    /// What went wrong and how to fix it, naming the wrapper and its file.
    let message: String

    /// Hears the issue of each call.
    let report: @MainActor (NavigationIssue) -> Void

    /// Reports a `noRouterInScope` issue at the call site and fails.
    func fail(file: StaticString, line: UInt) -> NavigationOutcome {
        let issue = NavigationIssue(
            kind: .noRouterInScope,
            flow: FlowID("unknown"),
            message: message,
            file: file,
            line: line
        )
        report(issue)
        return .failed(NavigationFailure(issue: issue))
    }
}

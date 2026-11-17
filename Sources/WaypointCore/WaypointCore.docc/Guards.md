# Guards

Allow, deny or redirect a navigation before it happens.

## Overview

A guard checks a change before the router applies it. Typical uses are asking the user to log in before a protected screen, confirming before leaving unsaved changes, and blocking a link to a feature that is turned off.

```swift
final class LoginGuard: NavigationGuard {
    let session: Session
    init(session: Session) { self.session = session }

    func evaluate(_ request: NavigationRequest) -> GuardDecision {
        guard request.targets(AccountRoute.self), !session.isLoggedIn else { return .allow }
        return .redirect(NavigationPlan { SwitchRoot(AppRoot.login) })
    }
}

root.addGuard(LoginGuard(session: session))
```

> Note: Guards are not available yet. This article fixes their shape so the rest of the API leaves room for them.

### Guard API

Guards are attached to a router and apply to it and everything below it. They are synchronous: an answer that needs to wait, such as a server check, is done by the app before it navigates, or by redirecting to a flow that does the check.

```swift
/// Checks changes before they are applied.
@MainActor
public protocol NavigationGuard: AnyObject {
    func evaluate(_ request: NavigationRequest) -> GuardDecision
}

/// A change waiting to be applied.
public struct NavigationRequest: Sendable {
    public let flow: FlowID
    public let change: NavigationChange
    public let origin: NavigationOrigin
    /// Whether the change shows a route of type `R`.
    public func targets<R: Route>(_ type: R.Type) -> Bool
}

/// A guard's answer.
public enum GuardDecision: Sendable, Equatable {
    case allow
    /// Refuses the change. The call returns `.failed` with a `denied` issue,
    /// unless its fallback applies.
    case deny(reason: String)
    /// Applies another plan instead. The original change is kept and resumed
    /// when the redirect flow finishes, if it still applies.
    case redirect(NavigationPlan)
}

extension StackRouter {   // also on TabRouter and RootRouter
    @discardableResult
    public func addGuard(_ guard: some NavigationGuard) -> GuardToken
}
```

### What guards can stop

Guards check every change that app code, deep links and restoration ask for. Changes the user makes by hand, such as swipe back, have already happened on screen. Guards can stop them only where the platform allows it, such as an interactive sheet dismissal.

A denied change emits a `navigationDenied` event, so logs and tests can see it.

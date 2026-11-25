//
//  AccountGate.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import Observation
import SwiftUI
import Waypoint

// Asks for an account only when an action needs one. Guests use the same app as signed-in readers;
// when a guest does something that needs an account, such as Check out, the gate holds the action,
// presents the accounts flow as a sheet, and runs the action once the sheet has closed after the
// reader signs in. Cancel drops the action. Waiting for the sheet to close first lets the action
// present its own screen, such as checkout full screen. The sheet says why it opened
// (`SignInReason`), and a toast over the tabs says "Signed in as" with the action that carries on,
// or "Signed out" after Sign out.
//
// The main tab router presents the accounts flow, a child flow `AuthFactory` builds, so it joins
// the app's one navigation tree and the gate gets the account it finishes with. An action inside a
// sheet can open the flow over that sheet instead (`requireAccount(for:over:then:done:)`), two
// levels deep: the sheet's router presents it, the action runs as soon as the reader signs in, and
// the flow shows Signed in, whose Done the caller runs to close both sheets. The sheet itself is
// still SwiftUI's, bound to the router, until Waypoint draws presented flows.
//
// Conformances:
// - `Observable` (from `@Observable`), so `MainTabView` presents and dismisses the accounts sheet,
//   and shows the notice.
// - `SheetAccountGating`, so a feature that only needs an account for an action, over its stack or
//   over a sheet, takes any gate, and its tests a fake.
// - `SessionAccountGating`, so the Account tab opens sign in and signs out without naming this
//   type.
@Observable
final class AccountGate: SheetAccountGating, SessionAccountGating {
    private static let noticeDuration = Duration.seconds(3)
    private static let signInTrigger = "sign_in"

    private let session: Session
    private let factory: AuthFactory
    private let tabs: TabRouter<MainTab>
    // `var` because `requireAccount(for:then:)` holds the action until the reader signs in or
    // cancels.
    private var heldAction: (() -> Void)?
    // `var` because signing in sets it, and `runHeldAction()` reads it once the sheet closes.
    private var didSignIn: Bool
    // `var` because `showSignIn(for:then:)` sets it with the flow the tab router presents, and
    // `finishAuth()` clears it once the sheet has slid away, so the sheet still draws meanwhile.
    private var presentedAuth: AuthCoordinator?
    // `var` for the same reason as `presentedAuth`: the sizes the presenting router gives the
    // sheet.
    private(set) var authSheetOptions: SheetOptions?
    // `var` for the same reason as `presentedAuth`: the sheet's router the flow opened over, or
    // `nil` when it opened over the tabs.
    private var authPresenter: StackRouter?
    // `var` because `showSignIn(for:then:)` keeps why the sheet opened until the reader signs in.
    private var reason: SignInReason
    // `var` because signing in and out set it, and its timer clears it.
    private(set) var notice: Notice?
    // `var` because each notice replaces the timer of the one before it.
    @ObservationIgnored private var noticeTimer: Task<Void, Never>?

    // Whether the accounts flow is presented over the tabs.
    var isShowingAuth: Bool {
        tabs.presented != nil
    }

    // The accounts flow over the tabs, which `MainTabView` draws.
    var tabsAuth: AuthCoordinator? {
        authPresenter == nil ? presentedAuth : nil
    }

    init(
        session: Session,
        factory: AuthFactory,
        tabs: TabRouter<MainTab>
    ) {
        self.session = session
        self.factory = factory
        self.tabs = tabs
        heldAction = nil
        didSignIn = false
        presentedAuth = nil
        authSheetOptions = nil
        authPresenter = nil
        reason = .account
        notice = nil
        noticeTimer = nil
    }

    func requireAccount(
        for reason: SignInReason,
        then action: @escaping () -> Void
    ) {
        guard !session.isSignedIn else {
            action()
            return
        }
        showSignIn(for: reason, then: action)
    }

    func showSignIn(
        for reason: SignInReason = .account,
        then action: (() -> Void)? = nil
    ) {
        hold(action, for: reason)
        let auth = factory.makeAuth(reason: reason)
        let outcome = tabs.present(auth, style: AppSheets.large, trigger: Self.signInTrigger) { result in
            self.authEnded(with: result)
        }
        guard outcome.didChange else {
            return
        }
        authSheetOptions = tabs.state.presentation.map { tabs.sheetOptions(for: $0) }
        presentedAuth = auth
    }

    // Like `requireAccount(for:then:)`, but a guest gets the accounts flow over `presenter`, the
    // router of the sheet the action is in. Once they sign in, the action runs at once and the flow
    // shows Signed in, whose Done runs `done`.
    func requireAccount(
        for reason: SignInReason,
        over presenter: StackRouter,
        then action: @escaping () -> Void,
        done: @escaping () -> Void
    ) {
        guard !session.isSignedIn else {
            action()
            return
        }
        hold(action, for: reason)
        let step = SignedInStep(
            onSignedIn: { _ in self.signedInOverSheet() },
            onDone: done
        )
        let auth = factory.makeAuth(reason: reason, signedInStep: step)
        let outcome = presenter.present(auth, style: AppSheets.large, trigger: Self.signInTrigger) { result in
            self.authEnded(with: result)
        }
        guard outcome.didChange else {
            return
        }
        authPresenter = presenter
        authSheetOptions = presenter.state.presentation.map { presenter.sheetOptions(for: $0) }
        presentedAuth = auth
    }

    // Whether the accounts flow is presented over the sheet `router` draws.
    func isShowingAuth(over router: StackRouter) -> Bool {
        authPresenter === router && router.presented != nil
    }

    // The accounts flow over the sheet `router` draws, which that sheet draws.
    func authFlow(over router: StackRouter) -> AnyView? {
        guard authPresenter === router, let presentedAuth else {
            return nil
        }
        return AnyView(AuthFlowView(auth: presentedAuth))
    }

    // Ends the session and says so; the reader stays where they are, as a guest.
    func signOut() {
        session.signOut()
        show(Notice(title: "Signed out", detail: nil))
    }

    func dismissAuth() {
        if let authPresenter {
            authPresenter.dismiss()
        } else {
            tabs.dismiss()
        }
    }

    // Takes the system's own dismissal of the sheet, a swipe down.
    func syncAuth(_ isShowing: Bool) {
        guard !isShowing else {
            return
        }
        dismissAuth()
    }

    // Once the sheet has gone: drops the flow, then runs the held action if the reader signed in.
    func finishAuth() {
        presentedAuth = nil
        authSheetOptions = nil
        authPresenter = nil
        runHeldAction()
    }

    // Once the accounts flow over the sheet `router` draws has gone, by itself or with that sheet.
    func finishAuth(over router: StackRouter) {
        guard authPresenter === router else {
            return
        }
        finishAuth()
    }

    private func hold(
        _ action: (() -> Void)?,
        for reason: SignInReason
    ) {
        heldAction = action
        didSignIn = false
        self.reason = reason
    }

    private func runHeldAction() {
        let action = didSignIn ? heldAction : nil
        heldAction = nil
        didSignIn = false
        action?()
    }

    // The flow over the tabs finished with the account: say so, and run the held action once the
    // sheet has gone. Cancel drops it.
    private func authEnded(with result: FlowResult<Account>) {
        guard case .finished(let account) = result else {
            return
        }
        didSignIn = true
        show(Notice(title: "Signed in as \(account.name)", detail: reason.resumedAction))
    }

    // Over another sheet, the action runs now and the flow stays to show Signed in.
    private func signedInOverSheet() {
        didSignIn = true
        runHeldAction()
    }

    private func show(_ notice: Notice) {
        self.notice = notice
        noticeTimer?.cancel()
        noticeTimer = Task { [weak self] in
            try? await Task.sleep(for: Self.noticeDuration)
            guard !Task.isCancelled else {
                return
            }
            self?.hideNotice()
        }
    }

    private func hideNotice() {
        notice = nil
    }
}

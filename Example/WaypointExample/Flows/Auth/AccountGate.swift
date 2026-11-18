//
//  AccountGate.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import Observation

// Asks for an account only when an action needs one. Guests use the same app as signed-in readers;
// when a guest does something that needs an account, such as Check out, the gate holds the action,
// presents the accounts flow as a sheet, and runs the action once the sheet has closed after the
// reader signs in. Cancel drops the action. Waiting for the sheet to close first lets the action
// present its own screen, such as checkout full screen.
//
// Conformances:
// - `Observable` (from `@Observable`), so `MainTabView` presents and dismisses the accounts sheet.
@MainActor
@Observable
final class AccountGate {
    private let session: Session
    private let service: any AuthService
    // `var` because `requireAccount(then:)` holds the action until the reader signs in or cancels.
    private var heldAction: (() -> Void)?
    // `var` because signing in sets it, and `runHeldAction()` reads it once the sheet closes.
    private var didSignIn: Bool
    // `var` because `showSignIn(then:)` presents the accounts flow, and signing in, Cancel and a
    // swipe down close it.
    private(set) var presentedAuth: AuthCoordinator?

    init(
        session: Session,
        service: any AuthService
    ) {
        self.session = session
        self.service = service
        heldAction = nil
        didSignIn = false
        presentedAuth = nil
    }

    func requireAccount(then action: @escaping () -> Void) {
        guard !session.isSignedIn else {
            action()
            return
        }
        showSignIn(then: action)
    }

    func showSignIn(then action: (() -> Void)? = nil) {
        heldAction = action
        didSignIn = false
        presentedAuth = AuthCoordinator(
            service: service,
            onSignedIn: { self.finishSigningIn(as: $0) },
            onCancel: { self.dismissAuth() }
        )
    }

    func dismissAuth() {
        presentedAuth = nil
    }

    func syncAuth(_ auth: AuthCoordinator?) {
        presentedAuth = auth
    }

    func runHeldAction() {
        let action = didSignIn ? heldAction : nil
        heldAction = nil
        didSignIn = false
        action?()
    }

    private func finishSigningIn(as account: Account) {
        session.signIn(account)
        didSignIn = true
        dismissAuth()
    }
}

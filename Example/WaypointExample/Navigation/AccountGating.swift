//
//  AccountGating.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import ExampleDesignSystem
import SwiftUI
import Waypoint

// What a feature asks of the account gate: run an action once the reader has an account, and the
// notice the gate shows after signing in or out. `AccountGate` is the app's; a test hands a
// feature a fake, so it controls whether the reader is signed in without presenting the accounts
// flow.
//
// Conformances:
// - `AnyObject`, so a feature shares the window's one gate, and reading `notice` follows it.
package protocol AccountGating: AnyObject {
    var notice: Notice? { get }

    func requireAccount(
        for reason: SignInReason,
        then action: @escaping () -> Void
    )
}

// An account gate that can also open the accounts flow over a sheet the feature presents, such as
// the wish list, and that the sheet draws. `AccountGate` is the app's; a test's fake runs or holds
// the action as `AccountGating` does and presents nothing.
//
// Conformances:
// - `AccountGating`, so the feature asks for an account the same way over the stack.
package protocol SheetAccountGating: AccountGating {
    var authSheetOptions: SheetOptions? { get }

    // Like `requireAccount(for:then:)`, but over `presenter`, the router of the sheet the action is
    // in. Once the reader signs in, the action runs and Done on Signed in runs `done`.
    func requireAccount(
        for reason: SignInReason,
        over presenter: StackRouter,
        then action: @escaping () -> Void,
        done: @escaping () -> Void
    )

    func isShowingAuth(over router: StackRouter) -> Bool

    // The accounts flow over the sheet `router` draws, ready for that sheet to show, or `nil` when
    // it isn't presented there. A view rather than the flow's coordinator, so a feature never names
    // the Auth feature's types.
    func authFlow(over router: StackRouter) -> AnyView?

    func syncAuth(_ isShowing: Bool)

    func finishAuth(over router: StackRouter)
}

// An account gate the Account tab drives itself: it opens sign in from the tab's own button and
// signs the reader out. `AccountGate` is the app's.
//
// Conformances:
// - `AccountGating`, so Account asks for an account the same way the other tabs do.
package protocol SessionAccountGating: AccountGating {
    func showSignIn(
        for reason: SignInReason,
        then action: (() -> Void)?
    )

    func signOut()
}

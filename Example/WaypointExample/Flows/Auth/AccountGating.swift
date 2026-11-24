//
//  AccountGating.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import WaypointCore

// What a feature asks of the account gate: run an action once the reader has an account, and the
// notice the gate shows after signing in or out. `AccountGate` is the app's; a test hands a
// feature a fake, so it controls whether the reader is signed in without presenting the accounts
// flow.
//
// Conformances:
// - `AnyObject`, so a feature shares the window's one gate, and reading `notice` follows it.
protocol AccountGating: AnyObject {
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
protocol SheetAccountGating: AccountGating {
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

    func auth(over router: StackRouter) -> AuthCoordinator?

    func syncAuth(_ isShowing: Bool)

    func finishAuth(over router: StackRouter)
}

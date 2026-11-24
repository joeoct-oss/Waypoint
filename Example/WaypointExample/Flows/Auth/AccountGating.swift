//
//  AccountGating.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

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

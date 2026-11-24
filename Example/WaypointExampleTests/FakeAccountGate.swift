//
//  FakeAccountGate.swift
//  WaypointExampleTests
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

@testable import WaypointExample

// An account gate whose reader is signed in or not, as the test sets. A signed-in reader's action
// runs at once; a guest's is held, as the app's gate does while the accounts flow is open, and
// never runs. It keeps each reason it was asked for.
//
// Conformances:
// - `AccountGating`, so a feature takes it in place of the app's gate.
final class FakeAccountGate: AccountGating {
    let isSignedIn: Bool
    // `var` because each request adds its reason. Only `requireAccount(for:then:)` changes it.
    private(set) var reasons: [SignInReason]

    var notice: Notice? {
        nil
    }

    init(isSignedIn: Bool) {
        self.isSignedIn = isSignedIn
        reasons = []
    }

    func requireAccount(
        for reason: SignInReason,
        then action: @escaping () -> Void
    ) {
        reasons.append(reason)
        guard isSignedIn else {
            return
        }
        action()
    }
}

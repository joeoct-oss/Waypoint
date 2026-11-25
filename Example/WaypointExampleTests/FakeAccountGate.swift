//
//  FakeAccountGate.swift
//  WaypointExampleTests
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import ExampleDesignSystem
import ExampleNavigation
import SwiftUI
import Waypoint
@testable import WaypointExample

// An account gate whose reader is signed in or not, as the test sets. A signed-in reader's action
// runs at once; a guest's is held, as the app's gate does while the accounts flow is open, and
// never runs. It keeps each reason it was asked for. Asked over a sheet, it does the same and
// presents nothing.
//
// Conformances:
// - `SheetAccountGating`, so a feature takes it in place of the app's gate.
final class FakeAccountGate: SheetAccountGating {
    let isSignedIn: Bool
    // `var` because each request adds its reason. Only `requireAccount(for:then:)` changes it.
    private(set) var reasons: [SignInReason]

    var notice: Notice? {
        nil
    }

    var authSheetOptions: SheetOptions? {
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

    func requireAccount(
        for reason: SignInReason,
        over presenter: StackRouter,
        then action: @escaping () -> Void,
        done: @escaping () -> Void
    ) {
        requireAccount(for: reason, then: action)
    }

    func isShowingAuth(over router: StackRouter) -> Bool {
        false
    }

    func authFlow(over router: StackRouter) -> AnyView? {
        nil
    }

    func syncAuth(_ isShowing: Bool) { }

    func finishAuth(over router: StackRouter) { }
}

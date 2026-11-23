//
//  ResetPasswordCoordinatorTests.swift
//  WaypointExampleTests
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import Testing
import Waypoint
@testable import WaypointExample

// Reset password is a child flow (#59): the accounts flow starts it, its router joins the
// accounts flow's tree, and the accounts flow gets the email the link went to, or `.cancelled`.
struct ResetPasswordCoordinatorTests {
    private static let email = "reader@example.com"

    @Test
    func doneAfterSendingFinishesWithTheEmail() {
        let store = TestStore.make()
        defer {
            store.clearAll()
        }
        let parent = StackRouter()
        let reset = ResetPasswordCoordinator(service: MockAuthService(store: store))
        let results = ResultLog()
        parent.present(reset) { result in
            results.record(result)
        }

        reset.sendLink(to: Self.email)
        reset.done()

        let expected: [FlowResult<String>] = [.finished(Self.email)]
        #expect(results.values == expected)
        #expect(parent.presented == nil)
    }

    @Test
    func cancelEndsTheFlowCancelled() {
        let store = TestStore.make()
        defer {
            store.clearAll()
        }
        let parent = StackRouter()
        let reset = ResetPasswordCoordinator(service: MockAuthService(store: store))
        let results = ResultLog()
        parent.present(reset) { result in
            results.record(result)
        }

        #expect(reset.router.parent === parent)
        #expect(reset.router.rootName == "Reset password")
        reset.cancel()

        let expected: [FlowResult<String>] = [.cancelled]
        #expect(results.values == expected)
    }

    @Test
    func secondTapKeepsTheFlowOnScreen() {
        let store = TestStore.make()
        defer {
            store.clearAll()
        }
        let auth = AuthCoordinator(
            router: StackRouter(),
            reason: .account,
            service: MockAuthService(store: store),
            onSignedIn: { _ in },
            onCancel: { }
        )
        auth.showResetPassword()
        let first = auth.resetPassword

        auth.showResetPassword()

        #expect(auth.resetPassword === first)
        #expect(auth.router.presented === first?.router)
    }
}

// The results the accounts flow got, oldest first.
final class ResultLog {
    // `var` because each ended flow adds its result. Only `record(_:)` changes it.
    private(set) var values: [FlowResult<String>] = []

    func record(_ result: FlowResult<String>) {
        values.append(result)
    }
}

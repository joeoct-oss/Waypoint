//
//  ResetPasswordCoordinatorTests.swift
//  WaypointExampleTests
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import ExampleServices
import Testing
import Waypoint
@testable import WaypointExample

// Reset password is a child flow (planning #313): the accounts flow starts it, its router joins the
// accounts flow's tree, and the accounts flow gets the email the link went to, or `.cancelled`.
struct ResetPasswordCoordinatorTests {
    private static let email = "reader@example.com"

    @Test("Done after sending finishes with the email and closes the flow")
    func doneAfterSendingFinishesWithTheEmail() {
        let store = TestStore.make()
        defer {
            store.clearAll()
        }
        let parent = StackRouter()
        let reset = Self.makeFactory(store: store).makeResetPassword()
        let results = ResultLog<String>()
        parent.present(reset) { result in
            results.record(result)
        }

        reset.sendLink(to: Self.email)
        reset.done()

        let expected: [FlowResult<String>] = [.finished(Self.email)]
        #expect(results.values == expected)
        #expect(parent.presented == nil)
    }

    @Test("Cancel ends the reset password flow cancelled")
    func cancelEndsTheFlowCancelled() {
        let store = TestStore.make()
        defer {
            store.clearAll()
        }
        let parent = StackRouter()
        let reset = Self.makeFactory(store: store).makeResetPassword()
        let results = ResultLog<String>()
        parent.present(reset) { result in
            results.record(result)
        }

        #expect(reset.router.parent === parent)
        #expect(reset.router.rootName == "Reset password")
        reset.cancel()

        let expected: [FlowResult<String>] = [.cancelled]
        #expect(results.values == expected)
    }

    @Test("A second tap keeps the same flow on screen")
    func secondTapKeepsTheFlowOnScreen() {
        let store = TestStore.make()
        defer {
            store.clearAll()
        }
        let auth = Self.makeFactory(store: store).makeAuth(reason: .account)
        // The app's rules replace a presentation that is already up.
        auth.router.setFallback(.replacePresentation, for: .alreadyPresenting)
        auth.showResetPassword()
        let first = auth.resetPassword

        auth.showResetPassword()

        #expect(auth.resetPassword === first)
        #expect(auth.router.presented === first?.router)
    }

    private static func makeFactory(store: LocalStore) -> AuthFactory {
        let dependencies = AuthDependencies(
            session: Session(store: store),
            service: MockAuthService(store: store)
        )
        return AuthFactory(dependencies: dependencies)
    }
}

// The results a parent flow got from its child flow, oldest first.
final class ResultLog<Value: Sendable> {
    // `var` because each ended flow adds its result. Only `record(_:)` changes it.
    private(set) var values: [FlowResult<Value>] = []

    func record(_ result: FlowResult<Value>) {
        values.append(result)
    }
}

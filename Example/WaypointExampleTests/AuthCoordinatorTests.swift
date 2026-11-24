//
//  AuthCoordinatorTests.swift
//  WaypointExampleTests
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import Testing
import Waypoint
@testable import WaypointExample

// The accounts flow, built by `AuthFactory` (planning #424): Create account keeps what the reader
// typed when they go back a step, and its last step signs the new account in and finishes the flow
// with it.
struct AuthCoordinatorTests {
    private static let name = "Ada"
    private static let email = "ada@example.com"
    private static let password = "orbit-2026"

    @Test
    func createAccountKeepsValuesGoingBack() {
        let store = TestStore.make()
        defer {
            store.clearAll()
        }
        let auth = makeFactory(store: store).makeAuth(reason: .account)
        let parent = StackRouter()
        parent.present(auth) { _ in }

        auth.showCreateAccount()
        auth.builder.draft.name = Self.name
        auth.builder.draft.email = Self.email
        auth.continueCreatingAccount(after: .details)
        auth.router.pop()

        let details = auth.builder.makeStep(
            .details,
            isWorking: false,
            errorMessage: nil,
            onContinue: { },
            onShowTerms: { }
        )
        let expectedPath = [
            AnyRoute(CreateAccountRoute(step: .details)),
        ]
        #expect(auth.router.state.path == expectedPath)
        #expect(details.draft.name == Self.name)
        #expect(details.draft.email == Self.email)
    }

    @Test
    func createAccountSignsInOnFinish() async throws {
        let store = TestStore.make()
        defer {
            store.clearAll()
        }
        let session = Session(store: store)
        let factory = AuthFactory(
            dependencies: AuthDependencies(
                session: session,
                service: MockAuthService(store: store)
            )
        )
        let auth = factory.makeAuth(reason: .account)
        let parent = StackRouter()
        let results = ResultLog<Account>()
        parent.present(auth) { result in
            results.record(result)
        }

        auth.showCreateAccount()
        auth.builder.draft.name = Self.name
        auth.builder.draft.email = Self.email
        auth.builder.draft.password = Self.password
        let account = try await auth.builder.register()
        auth.continueCreatingAccount(after: .checkEmail)

        let expected: [FlowResult<Account>] = [
            .finished(account),
        ]
        #expect(results.values == expected)
        #expect(session.account == account)
        #expect(parent.presented == nil)
    }

    private func makeFactory(store: LocalStore) -> AuthFactory {
        AuthFactory(
            dependencies: AuthDependencies(
                session: Session(store: store),
                service: MockAuthService(store: store)
            )
        )
    }
}

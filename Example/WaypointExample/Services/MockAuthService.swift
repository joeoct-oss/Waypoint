//
//  MockAuthService.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//


import ExampleStore
import Foundation

// A stand-in for an auth server, so every journey runs without a network. Each call waits a
// moment, like a request would. Any email and password sign in, except the password `wrong`,
// which shows the error path. Creating an account fails for an email already registered on this
// device.
//
// Conformances:
// - `AuthService`, so the accounts flow can use it in place of a real server.
package final class MockAuthService: AuthService {
    package static let wrongPassword = "wrong"

    private static let delay = Duration.milliseconds(400)

    private static func makeName(for email: String) -> String {
        let name = email.split(separator: "@").first.map(String.init) ?? email
        return name.capitalized
    }

    private let store: LocalStore

    package init(store: LocalStore) {
        self.store = store
    }

    package func signIn(
        email: String,
        password: String
    ) async throws(AuthError) -> Account {
        try? await Task.sleep(for: Self.delay)
        guard password != Self.wrongPassword else {
            throw .wrongPassword
        }
        return Account(
            name: Self.makeName(for: email),
            email: email
        )
    }

    package func register(
        name: String,
        email: String,
        password: String
    ) async throws(AuthError) -> Account {
        try? await Task.sleep(for: Self.delay)
        guard !store.registeredEmails.contains(email) else {
            throw .emailTaken
        }
        store.registeredEmails.append(email)
        return Account(
            name: name,
            email: email
        )
    }

    package func sendResetLink(to email: String) async {
        try? await Task.sleep(for: Self.delay)
    }
}

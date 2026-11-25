//
//  AuthService.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//


import ExampleStore
import Foundation

// Signs readers in, creates accounts and sends reset links. The example app uses
// `MockAuthService`; a real app would put its server behind the same three calls.
package protocol AuthService {
    func signIn(
        email: String,
        password: String
    ) async throws(AuthError) -> Account

    func register(
        name: String,
        email: String,
        password: String
    ) async throws(AuthError) -> Account

    func sendResetLink(to email: String) async
}

// Why signing in or creating an account failed.
//
// Conformances:
// - `Error`, so the auth service can throw it.
package enum AuthError: Error {
    case wrongPassword
    case emailTaken

    package var message: String {
        switch self {
        case .wrongPassword:
            return "That email and password don't match."
        case .emailTaken:
            return "An account with that email already exists. Sign in instead."
        }
    }
}

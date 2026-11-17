//
//  AuthCoordinator.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <52625092+JoeOCT91@users.noreply.github.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import SwiftUI

// The sign-in flow: sign in at the root, with create account and forgot password pushed above it. When
// the reader signs in or creates an account, the flow reports it and the app coordinator switches the root.
//
// Conformances:
// - `Observable` (from `@Observable`), so `AuthFlowView` redraws when the path changes.
@MainActor
@Observable
final class AuthCoordinator {
    private let onSignedIn: () -> Void
    // `var` because `showCreateAccount()` and `showForgotPassword()` push onto it, and `syncPath(_:)` takes
    // the pops the stack makes itself.
    private(set) var path: [AuthScreen]

    init(onSignedIn: @escaping () -> Void) {
        self.onSignedIn = onSignedIn
        path = []
    }

    func makeSignInFlow() -> some View {
        SignInView(
            onSignIn: { self.finishSignIn() },
            onCreateAccount: { self.showCreateAccount() },
            onForgotPassword: { self.showForgotPassword() }
        )
        .screenChrome(
            title: "Sign in",
            kind: nil,
            trail: AuthTrail.signIn
        )
    }

    @ViewBuilder
    func makeDestination(for screen: AuthScreen) -> some View {
        switch screen {
        case .createAccount:
            makeCreateAccountFlow()
        case .forgotPassword:
            makeForgotPasswordFlow()
        }
    }

    func showCreateAccount() {
        path.append(.createAccount)
    }

    func showForgotPassword() {
        path.append(.forgotPassword)
    }

    func showSignIn() {
        path = []
    }

    func finishSignIn() {
        onSignedIn()
    }

    func syncPath(_ newPath: [AuthScreen]) {
        path = newPath
    }

    private func makeCreateAccountFlow() -> some View {
        CreateAccountView(onCreate: { self.finishSignIn() })
            .screenChrome(
                title: "Create account",
                kind: nil,
                trail: AuthTrail.createAccount
            )
    }

    private func makeForgotPasswordFlow() -> some View {
        ForgotPasswordView(onSent: { self.showSignIn() })
            .screenChrome(
                title: "Reset password",
                kind: nil,
                trail: AuthTrail.forgotPassword
            )
    }
}

// The route trail for each sign-in screen.
enum AuthTrail {
    static let signIn = [
        "sign in",
    ]
    static let createAccount = [
        "sign in",
        "create account",
    ]
    static let forgotPassword = [
        "sign in",
        "reset password",
    ]
}

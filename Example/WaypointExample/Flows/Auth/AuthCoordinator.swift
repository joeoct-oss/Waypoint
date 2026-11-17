//
//  AuthCoordinator.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <52625092+JoeOCT91@users.noreply.github.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import SwiftUI

// The accounts flow: Welcome at the root, with Sign in and the three steps of Create account pushed above
// it, and Forgot password as a sheet over Sign in. Every way out (signing in, creating an account or
// continuing as a guest) reports to the app coordinator, which switches the root once.
//
// Conformances:
// - `Observable` (from `@Observable`), so `AuthFlowView` redraws when the path or the sheet changes.
@MainActor
@Observable
final class AuthCoordinator {
    private let onFinish: (Membership) -> Void
    // `var` because the `show…()` functions push onto it, and `syncPath(_:)` takes the pops the stack makes
    // itself.
    private(set) var path: [AuthScreen]
    // `var` because `showForgotPassword()` and `dismissForgotPassword()` change it, and
    // `syncForgotPassword(_:)` takes a swipe down.
    private(set) var isShowingForgotPassword: Bool

    init(onFinish: @escaping (Membership) -> Void) {
        self.onFinish = onFinish
        path = []
        isShowingForgotPassword = false
    }

    func makeWelcomeFlow() -> some View {
        WelcomeView(
            onCreateAccount: { self.showCreateAccount() },
            onSignIn: { self.showSignIn() },
            onContinueAsGuest: { self.finish(as: .guest) }
        )
        .background(Palette.background.color)
        .toolbar(.hidden, for: .navigationBar)
    }

    func makeDestination(for screen: AuthScreen) -> some View {
        makeScreen(for: screen)
            .screenChrome(
                title: screen.title,
                kind: nil,
                trail: screen.trail
            )
    }

    func makeForgotPasswordFlow() -> some View {
        ForgotPasswordView(
            onSent: { self.dismissForgotPassword() },
            onCancel: { self.dismissForgotPassword() }
        )
    }

    func showSignIn() {
        path.append(.signIn)
    }

    func showCreateAccount() {
        path.append(.createAccount(.name))
    }

    func showForgotPassword() {
        isShowingForgotPassword = true
    }

    func finish(as membership: Membership) {
        onFinish(membership)
    }

    func dismissForgotPassword() {
        isShowingForgotPassword = false
    }

    func syncPath(_ newPath: [AuthScreen]) {
        path = newPath
    }

    func syncForgotPassword(_ isShowing: Bool) {
        isShowingForgotPassword = isShowing
    }

    @ViewBuilder
    private func makeScreen(for screen: AuthScreen) -> some View {
        switch screen {
        case .signIn:
            makeSignInFlow()
        case .createAccount(let step):
            makeCreateAccountFlow(step)
        }
    }

    private func makeSignInFlow() -> some View {
        SignInView(
            onSignIn: { self.finish(as: .member) },
            onForgotPassword: { self.showForgotPassword() }
        )
    }

    private func makeCreateAccountFlow(_ step: CreateAccountStep) -> some View {
        CreateAccountStepView(
            step: step,
            onContinue: { self.continueCreatingAccount(after: step) }
        )
    }

    private func continueCreatingAccount(after step: CreateAccountStep) {
        guard let next = step.next else {
            finish(as: .member)
            return
        }
        path.append(.createAccount(next))
    }
}

//
//  AuthCoordinator.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import SwiftUI

// The accounts flow: Welcome at the root, with Sign in and the three steps of Create account pushed
// above it, Reset password as a sheet over Sign in, and the terms as a sheet over Choose a
// password. The steps share one draft, so going back keeps what the reader typed. Every way out
// (signing in, creating an account or continuing as a guest) reports to the app coordinator, which
// switches the root once.
//
// Conformances:
// - `Observable` (from `@Observable`), so `AuthFlowView` redraws when the path or the sheet
//   changes.
@MainActor
@Observable
final class AuthCoordinator {
    private let onFinish: (Membership) -> Void
    private let draft: SignUpDraft
    // `var` because the `show…()` functions push onto it, and `syncPath(_:)` takes the pops the
    // stack makes itself.
    private(set) var path: [AuthScreen]
    // `var` because `showResetPassword()`, `showTerms()` and `dismissSheet()` change it, and
    // `syncSheet(_:)` takes a swipe down.
    private(set) var presentedSheet: AuthSheet?

    init(onFinish: @escaping (Membership) -> Void) {
        self.onFinish = onFinish
        draft = SignUpDraft()
        path = []
        presentedSheet = nil
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

    @ViewBuilder
    func makeSheetFlow(for sheet: AuthSheet) -> some View {
        switch sheet {
        case .resetPassword:
            makeResetPasswordFlow()
        case .terms:
            makeTermsFlow()
        }
    }

    func showSignIn() {
        path.append(.signIn)
    }

    func showCreateAccount() {
        path.append(.createAccount(.details))
    }

    func showResetPassword() {
        presentedSheet = .resetPassword
    }

    func showTerms() {
        presentedSheet = .terms
    }

    func finish(as membership: Membership) {
        onFinish(membership)
    }

    func dismissSheet() {
        presentedSheet = nil
    }

    func syncPath(_ newPath: [AuthScreen]) {
        path = newPath
    }

    func syncSheet(_ sheet: AuthSheet?) {
        presentedSheet = sheet
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
            onForgotPassword: { self.showResetPassword() }
        )
    }

    private func makeCreateAccountFlow(_ step: CreateAccountStep) -> some View {
        CreateAccountStepView(
            step: step,
            draft: draft,
            onContinue: { self.continueCreatingAccount(after: step) },
            onShowTerms: { self.showTerms() }
        )
    }

    private func makeResetPasswordFlow() -> some View {
        ForgotPasswordView(
            onDone: { self.dismissSheet() },
            onCancel: { self.dismissSheet() }
        )
    }

    private func makeTermsFlow() -> some View {
        TermsView(onDone: { self.dismissSheet() })
    }

    private func continueCreatingAccount(after step: CreateAccountStep) {
        guard let next = step.next else {
            finish(as: .member)
            return
        }
        path.append(.createAccount(next))
    }
}

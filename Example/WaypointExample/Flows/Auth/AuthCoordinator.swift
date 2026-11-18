//
//  AuthCoordinator.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import SwiftUI

// The accounts flow, presented as a sheet when the reader does something that needs an account:
// Sign in at the root, the three steps of Create account pushed above it, Reset password as a sheet
// over Sign in, and the terms as a sheet over Choose a password. The steps share one draft, so
// going back keeps what the reader typed. Signing in and creating an account go through the auth
// service; the flow reports the account, or Cancel, to the account gate that presented it.
//
// Conformances:
// - `Observable` (from `@Observable`), so `AuthFlowView` redraws when the path, a sheet, the error
//   or the busy state changes.
// - `Identifiable` (an object's identity), so the main tabs can present the flow with
//   `.sheet(item:)`.
@MainActor
@Observable
final class AuthCoordinator: Identifiable {
    private let service: any AuthService
    private let onSignedIn: (Account) -> Void
    private let onCancel: () -> Void
    private let draft: SignUpDraft
    // `var` because creating an account keeps it until Check your email reports Start shopping.
    private var newAccount: Account?
    // `var` because the `show…()` functions push onto it, and `syncPath(_:)` takes the pops the
    // stack makes itself.
    private(set) var path: [AuthScreen]
    // `var` because `showResetPassword()`, `showTerms()` and `dismissSheet()` change it, and
    // `syncSheet(_:)` takes a swipe down.
    private(set) var presentedSheet: AuthSheet?
    // `var` because a call to the auth service sets it while the call runs.
    private(set) var isWorking: Bool
    // `var` because a failed call to the auth service sets it, and the next call clears it.
    private(set) var errorMessage: String?

    init(
        service: any AuthService,
        onSignedIn: @escaping (Account) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.service = service
        self.onSignedIn = onSignedIn
        self.onCancel = onCancel
        draft = SignUpDraft()
        newAccount = nil
        path = []
        presentedSheet = nil
        isWorking = false
        errorMessage = nil
    }

    func makeSignInFlow() -> some View {
        SignInView(
            isWorking: isWorking,
            errorMessage: errorMessage,
            onSignIn: { self.signIn(email: $0, password: $1) },
            onCreateAccount: { self.showCreateAccount() },
            onForgotPassword: { self.showResetPassword() },
            onCancel: { self.cancel() }
        )
        .screenChrome(
            title: "Sign in",
            kind: nil,
            trail: AuthTrail.signIn
        )
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

    func showCreateAccount() {
        errorMessage = nil
        path.append(.createAccount(.details))
    }

    func showResetPassword() {
        presentedSheet = .resetPassword
    }

    func showTerms() {
        presentedSheet = .terms
    }

    func signIn(
        email: String,
        password: String
    ) {
        Task {
            await runSignIn(
                email: email,
                password: password
            )
        }
    }

    func cancel() {
        onCancel()
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
        case .createAccount(let step):
            makeCreateAccountFlow(step)
        }
    }

    private func makeCreateAccountFlow(_ step: CreateAccountStep) -> some View {
        CreateAccountStepView(
            step: step,
            draft: draft,
            isWorking: isWorking,
            errorMessage: errorMessage,
            onContinue: { self.continueCreatingAccount(after: step) },
            onShowTerms: { self.showTerms() }
        )
    }

    private func makeResetPasswordFlow() -> some View {
        ForgotPasswordView(
            onSend: { self.sendResetLink(to: $0) },
            onDone: { self.dismissSheet() },
            onCancel: { self.dismissSheet() }
        )
    }

    private func makeTermsFlow() -> some View {
        TermsView(onDone: { self.dismissSheet() })
    }

    private func continueCreatingAccount(after step: CreateAccountStep) {
        switch step {
        case .details:
            showStep(.password)
        case .password:
            register()
        case .checkEmail:
            finishCreatingAccount()
        }
    }

    private func showStep(_ step: CreateAccountStep) {
        errorMessage = nil
        path.append(.createAccount(step))
    }

    private func register() {
        Task {
            await runRegister()
        }
    }

    private func finishCreatingAccount() {
        guard let newAccount else {
            return
        }
        onSignedIn(newAccount)
    }

    private func sendResetLink(to email: String) {
        Task {
            await service.sendResetLink(to: email)
        }
    }

    private func runSignIn(
        email: String,
        password: String
    ) async {
        isWorking = true
        defer {
            isWorking = false
        }
        do {
            let account = try await service.signIn(
                email: email,
                password: password
            )
            errorMessage = nil
            onSignedIn(account)
        } catch {
            errorMessage = error.message
        }
    }

    private func runRegister() async {
        isWorking = true
        defer {
            isWorking = false
        }
        do {
            newAccount = try await service.register(
                name: draft.name,
                email: draft.email,
                password: draft.password
            )
            showStep(.checkEmail)
        } catch {
            errorMessage = error.message
        }
    }
}

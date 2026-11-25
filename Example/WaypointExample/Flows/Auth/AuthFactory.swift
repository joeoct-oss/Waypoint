//
//  AuthFactory.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import SwiftUI

// Builds the accounts flow and its screens from `AuthDependencies`: the flow's coordinator, its
// Create account builder, Sign in, Signed in, the terms, Reset password's coordinator and screen,
// and the view that draws the flow in its sheet. The coordinator passes in what each screen
// reports, so navigation stays in the coordinator.
struct AuthFactory {
    // What the feature uses, which its coordinator reads too.
    let dependencies: AuthDependencies

    init(dependencies: AuthDependencies) {
        self.dependencies = dependencies
    }

    // The accounts flow, opened because of `reason`. With `signedInStep`, signing in keeps the
    // flow open on Signed in instead of finishing it.
    func makeAuth(
        reason: SignInReason,
        signedInStep: SignedInStep? = nil
    ) -> AuthCoordinator {
        AuthCoordinator(
            factory: self,
            request: AuthRequest(
                reason: reason,
                signedInStep: signedInStep
            )
        )
    }

    // A new Create account journey, which keeps what the reader types across its steps.
    func makeCreateAccountBuilder() -> CreateAccountBuilder {
        CreateAccountBuilder(service: dependencies.service)
    }

    func makeSignIn(
        reason: SignInReason,
        isWorking: Bool,
        errorMessage: String?,
        onSignIn: @escaping (String, String) -> Void,
        onCreateAccount: @escaping () -> Void,
        onForgotPassword: @escaping () -> Void,
        onCancel: @escaping () -> Void
    ) -> SignInView {
        SignInView(
            reason: reason,
            isWorking: isWorking,
            errorMessage: errorMessage,
            onSignIn: onSignIn,
            onCreateAccount: onCreateAccount,
            onForgotPassword: onForgotPassword,
            onCancel: onCancel
        )
    }

    func makeSignedIn(
        name: String,
        reason: SignInReason,
        onDone: @escaping () -> Void
    ) -> SignedInView {
        SignedInView(
            name: name,
            resumedAction: reason.resumedAction,
            onDone: onDone
        )
    }

    func makeTerms(onDone: @escaping () -> Void) -> TermsView {
        TermsView(onDone: onDone)
    }

    func makeResetPassword() -> ResetPasswordCoordinator {
        ResetPasswordCoordinator(factory: self)
    }

    // Reset password's one screen: Send link sends `onSend` the email.
    func makeForgotPassword(
        onSend: @escaping (String) -> Void,
        onDone: @escaping () -> Void,
        onCancel: @escaping () -> Void
    ) -> ForgotPasswordView {
        ForgotPasswordView(
            onSend: onSend,
            onDone: onDone,
            onCancel: onCancel
        )
    }

    // Draws the accounts flow `auth`, in the sheet its gate presents.
    func makeAuthFlow(_ auth: AuthCoordinator) -> AuthFlowView {
        AuthFlowView(auth: auth)
    }
}

// What the accounts flow does when it opened over another sheet: signing in runs `onSignedIn` at
// once and shows Signed in, whose Done runs `onDone`, so the caller closes both sheets together.
struct SignedInStep {
    let onSignedIn: (Account) -> Void
    let onDone: () -> Void
}

//
//  AuthFactory.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import ExampleNavigation
import ExampleStore
import SwiftUI

// Builds the accounts flow and its screens from `AuthDependencies`: the flow's coordinator, its
// Create account builder, Sign in, Signed in, the terms, and Reset password's coordinator and
// screen. The coordinator passes in what each screen reports, so navigation stays in the
// coordinator.
package struct AuthFactory {
    // What the feature uses, which its coordinator reads too.
    package let dependencies: AuthDependencies

    package init(dependencies: AuthDependencies) {
        self.dependencies = dependencies
    }

    // The accounts flow, opened because of `reason`. With `signedInStep`, signing in keeps the
    // flow open on Signed in instead of finishing it.
    package func makeAuth(
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

    // What Sign in and Create account show of a call to the auth service, for one accounts flow.
    package func makeForm() -> AuthForm {
        AuthForm()
    }

    // A new Create account journey, which keeps what the reader types across its steps.
    package func makeCreateAccountBuilder() -> CreateAccountBuilder {
        CreateAccountBuilder(service: dependencies.service)
    }

    package func makeSignIn(
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

    package func makeSignedIn(
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

    package func makeTerms(onDone: @escaping () -> Void) -> TermsView {
        TermsView(onDone: onDone)
    }

    package func makeResetPassword() -> ResetPasswordCoordinator {
        ResetPasswordCoordinator(factory: self)
    }

    // Reset password's one screen: Send link sends `onSend` the email.
    package func makeForgotPassword(
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
}

// What the accounts flow does when it opened over another sheet: signing in runs `onSignedIn` at
// once and shows Signed in, whose Done runs `onDone`, so the caller closes both sheets together.
package struct SignedInStep {
    package let onSignedIn: (Account) -> Void
    package let onDone: () -> Void
}

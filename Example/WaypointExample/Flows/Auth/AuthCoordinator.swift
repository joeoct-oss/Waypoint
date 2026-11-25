//
//  AuthCoordinator.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import ExampleDesignSystem
import ExampleNavigation
import ExampleServices
import ExampleStore
import SwiftUI
import Waypoint

// The accounts flow, presented as a sheet when the reader does something that needs an account:
// Sign in at the root, the three steps of Create account pushed above it, Reset password as a sheet
// over Sign in, and the terms as a sheet over Choose a password. The steps share one Create account
// builder, so going back keeps what the reader typed. Signing in and creating an account go through
// the auth service and sign the session in; the flow then finishes with the account, and Cancel or
// a swipe down ends it, which the account gate that presented it gets as `.cancelled`. When the
// gate opened the flow over another sheet, signing in instead pushes Signed in, whose Done the gate
// passes on to whoever opened the sheets, so they close together.
//
// `AuthFactory` builds the flow and each of its screens; the flow passes in what each screen
// reports. The steps are `CreateAccountRoute` pushes, and the terms is a route this flow's router
// presents. Reset password is a child flow with a coordinator of its own, which this router starts
// and gets the result of. The sheets themselves are still SwiftUI's, bound to the routers, until
// Waypoint draws them.
//
// Conformances:
// - `FlowCoordinator`, so the account gate presents it with `present(_:style:onFinish:)` and gets
//   the account.
// - `Observable` (from `@Observable`), so the flow redraws when Reset password or the signed-in
//   account changes.
@Observable
package final class AuthCoordinator: FlowCoordinator {
    // The account the reader signed in to, or created.
    package typealias Output = Account

    private let session: Session
    private let service: any AuthService
    private let factory: AuthFactory
    package let builder: CreateAccountBuilder
    private let reason: SignInReason
    private let signedInStep: SignedInStep?
    // Reset password or the terms, which `showResetPassword()` and `showTerms()` keep and
    // `releaseSheet()` drops once the sheet has slid away, so it still draws meanwhile.
    package let sheet: PresentedSheet<AuthSheet>
    // `var` for the same reason as `sheet`: Reset password's coordinator, which draws that sheet.
    package private(set) var resetPassword: ResetPasswordCoordinator?
    // `var` because signing in over another sheet sets it with the account Signed in names.
    private var signedInAccount: Account?
    // Whether a call to the auth service is running, and the last failure's message.
    package let form: AuthForm

    // The journey's name for Sign in, the flow's first screen.
    package var rootName: String {
        "Sign in"
    }

    package var root: some View {
        factory.makeSignIn(
            reason: reason,
            isWorking: form.isWorking,
            errorMessage: form.errorMessage,
            onSignIn: { self.signIn(email: $0, password: $1) },
            onCreateAccount: { self.showCreateAccount() },
            onForgotPassword: { self.showResetPassword() },
            onCancel: { self.cancel() }
        )
        .screenChrome(
            title: rootName,
            kind: nil,
            router: router,
            route: nil
        )
    }

    package var destinations: some Destinations {
        Destination(CreateAccountRoute.self) { self.makeCreateAccountScreen($0) }
        Destination(SignedInRoute.self) { _ in self.makeSignedInScreen() }
    }

    // Whether Reset password or the terms is presented over the flow.
    package var isShowingSheet: Bool {
        router.presented != nil
    }

    // `AuthFactory` makes it, hands it the feature's dependencies and its Create account builder,
    // and passes in why it opened.
    package init(
        factory: AuthFactory,
        request: AuthRequest
    ) {
        session = factory.dependencies.session
        service = factory.dependencies.service
        self.factory = factory
        builder = factory.makeCreateAccountBuilder()
        reason = request.reason
        signedInStep = request.signedInStep
        sheet = PresentedSheet()
        resetPassword = nil
        signedInAccount = nil
        form = factory.makeForm()
    }

    // Also registers the terms, which this router presents rather than pushes.
    package func registerDestinations(on router: StackRouter) {
        destinations.registerRoutes(on: router)
        router.register(TermsRoute.self)
    }

    package func makeCreateAccountScreen(_ route: CreateAccountRoute) -> some View {
        builder.makeStep(
            route.step,
            isWorking: form.isWorking,
            errorMessage: form.errorMessage,
            onContinue: { self.continueCreatingAccount(after: route.step) },
            onShowTerms: { self.showTerms() }
        )
        .screenChrome(
            title: route.title,
            kind: nil,
            router: router,
            route: AnyRoute(route)
        )
    }

    package func makeSignedInScreen() -> some View {
        factory.makeSignedIn(
            name: signedInAccount?.name ?? Account.sample.name,
            reason: reason,
            onDone: { self.signedInStep?.onDone() }
        )
        .screenChrome(
            title: SignedInRoute.screenName,
            kind: nil,
            router: router,
            route: AnyRoute(SignedInRoute())
        )
    }

    @ViewBuilder
    package func makeSheetFlow() -> some View {
        if let sheetRouter = sheet.router, let presentedSheet = sheet.sheet {
            WaypointStack(sheetRouter) {
                makeSheetScreen(for: presentedSheet)
            }
            .sheetOptions(sheet.options)
        }
    }

    package func showCreateAccount() {
        form.clearError()
        router.push(CreateAccountRoute(step: .details))
    }

    // Starts Reset password as a child flow. A link it sent clears a sign-in error, since the
    // reader is choosing a new password.
    package func showResetPassword() {
        let reset = factory.makeResetPassword()
        // No fallback, so a second tap while the sheet is up is refused and keeps the flow on
        // screen, with what the reader typed, instead of the app's `.replacePresentation`.
        let outcome = router.present(reset, style: .sheet, else: NavigationFallback.none) { result in
            self.resetPasswordEnded(with: result)
        }
        guard outcome.didChange else {
            return
        }
        resetPassword = reset
        sheet.keep(.resetPassword, presentedBy: router)
    }

    package func showTerms() {
        router.present(TermsRoute(), style: AppSheets.terms)
        sheet.keep(.terms, presentedBy: router)
    }

    package func signIn(
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

    // Cancel: ends the flow, which the account gate gets as `.cancelled`.
    package func cancel() {
        router.dismissFlow()
    }

    // Signs the session in, then finishes with the account, or, over another sheet, runs what the
    // gate asked for and shows Signed in.
    package func signedIn(as account: Account) {
        session.signIn(account)
        guard let signedInStep else {
            finish(with: account)
            return
        }
        signedInStep.onSignedIn(account)
        signedInAccount = account
        router.push(SignedInRoute())
    }

    package func dismissSheet() {
        router.dismiss()
    }

    // Takes the system's own dismissal of the sheet, a swipe down.
    package func syncSheet(_ isShowing: Bool) {
        guard !isShowing else {
            return
        }
        dismissSheet()
    }

    // Drops the sheet's router once the sheet has gone.
    package func releaseSheet() {
        sheet.release()
        resetPassword = nil
    }

    @ViewBuilder
    private func makeSheetScreen(for sheet: AuthSheet) -> some View {
        switch sheet {
        case .resetPassword:
            if let resetPassword {
                resetPassword.root
            }
        case .terms:
            factory.makeTerms(onDone: { self.dismissSheet() })
        }
    }

    // Continue on a Create account step: the next step, registering the account, or signing in.
    package func continueCreatingAccount(after step: CreateAccountStep) {
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
        form.clearError()
        router.push(CreateAccountRoute(step: step))
    }

    private func register() {
        Task {
            await runRegister()
        }
    }

    private func finishCreatingAccount() {
        guard let account = builder.account else {
            return
        }
        signedIn(as: account)
    }

    private func resetPasswordEnded(with result: FlowResult<String>) {
        guard case .finished = result else {
            return
        }
        form.clearError()
    }

    private func runSignIn(
        email: String,
        password: String
    ) async {
        await form.run { () async throws(AuthError) in
            let account = try await service.signIn(
                email: email,
                password: password
            )
            form.clearError()
            signedIn(as: account)
        }
    }

    private func runRegister() async {
        await form.run { () async throws(AuthError) in
            try await builder.register()
            showStep(.checkEmail)
        }
    }
}

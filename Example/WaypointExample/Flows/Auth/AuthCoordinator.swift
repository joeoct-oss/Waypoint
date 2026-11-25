//
//  AuthCoordinator.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

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
// - `Observable` (from `@Observable`), so the flow redraws when a sheet, the error or the busy
//   state changes.
@Observable
final class AuthCoordinator: FlowCoordinator {
    // The account the reader signed in to, or created.
    typealias Output = Account

    private let session: Session
    private let service: any AuthService
    private let factory: AuthFactory
    let builder: CreateAccountBuilder
    private let reason: SignInReason
    private let signedInStep: SignedInStep?
    // `var` because `showResetPassword()` and `showTerms()` set it with the router they present,
    // and `releaseSheet()` clears both once the sheet has slid away, so it still draws meanwhile.
    private(set) var presentedSheet: AuthSheet?
    // `var` for the same reason as `presentedSheet`: the presented sheet's router.
    private(set) var sheetRouter: StackRouter?
    // `var` for the same reason as `presentedSheet`: the sizes the router gives the sheet.
    private(set) var sheetOptions: SheetOptions?
    // `var` for the same reason as `presentedSheet`: Reset password's coordinator, which draws
    // that sheet.
    private(set) var resetPassword: ResetPasswordCoordinator?
    // `var` because signing in over another sheet sets it with the account Signed in names.
    private var signedInAccount: Account?
    // `var` because a call to the auth service sets it while the call runs.
    private(set) var isWorking: Bool
    // `var` because a failed call to the auth service sets it, and the next call clears it.
    private(set) var errorMessage: String?

    // The journey's name for Sign in, the flow's first screen.
    var rootName: String {
        "Sign in"
    }

    var root: some View {
        factory.makeSignIn(
            reason: reason,
            isWorking: isWorking,
            errorMessage: errorMessage,
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

    var destinations: some Destinations {
        Destination(CreateAccountRoute.self) { self.makeCreateAccountScreen($0) }
        Destination(SignedInRoute.self) { _ in self.makeSignedInScreen() }
    }

    // Whether Reset password or the terms is presented over the flow.
    var isShowingSheet: Bool {
        router.presented != nil
    }

    // `AuthFactory` makes it, hands it the feature's dependencies and its Create account builder,
    // and passes in why it opened.
    init(
        factory: AuthFactory,
        request: AuthRequest
    ) {
        session = factory.dependencies.session
        service = factory.dependencies.service
        self.factory = factory
        builder = factory.makeCreateAccountBuilder()
        reason = request.reason
        signedInStep = request.signedInStep
        presentedSheet = nil
        sheetRouter = nil
        sheetOptions = nil
        resetPassword = nil
        signedInAccount = nil
        isWorking = false
        errorMessage = nil
    }

    // Also registers the terms, which this router presents rather than pushes.
    func registerDestinations(on router: StackRouter) {
        destinations.registerRoutes(on: router)
        router.register(TermsRoute.self)
    }

    func makeCreateAccountScreen(_ route: CreateAccountRoute) -> some View {
        builder.makeStep(
            route.step,
            isWorking: isWorking,
            errorMessage: errorMessage,
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

    func makeSignedInScreen() -> some View {
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
    func makeSheetFlow() -> some View {
        if let sheetRouter, let presentedSheet {
            WaypointStack(sheetRouter) {
                makeSheetScreen(for: presentedSheet)
            }
            .sheetOptions(sheetOptions)
        }
    }

    func showCreateAccount() {
        errorMessage = nil
        router.push(CreateAccountRoute(step: .details))
    }

    // Starts Reset password as a child flow. A link it sent clears a sign-in error, since the
    // reader is choosing a new password.
    func showResetPassword() {
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
        keepPresentedSheet(.resetPassword)
    }

    func showTerms() {
        router.present(TermsRoute(), style: AppSheets.terms)
        keepPresentedSheet(.terms)
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

    // Cancel: ends the flow, which the account gate gets as `.cancelled`.
    func cancel() {
        router.dismissFlow()
    }

    // Signs the session in, then finishes with the account, or, over another sheet, runs what the
    // gate asked for and shows Signed in.
    func signedIn(as account: Account) {
        session.signIn(account)
        guard let signedInStep else {
            finish(with: account)
            return
        }
        signedInStep.onSignedIn(account)
        signedInAccount = account
        router.push(SignedInRoute())
    }

    func dismissSheet() {
        router.dismiss()
    }

    // Takes the system's own dismissal of the sheet, a swipe down.
    func syncSheet(_ isShowing: Bool) {
        guard !isShowing else {
            return
        }
        dismissSheet()
    }

    // Drops the sheet's router once the sheet has gone.
    func releaseSheet() {
        presentedSheet = nil
        sheetRouter = nil
        sheetOptions = nil
        resetPassword = nil
    }

    // Keeps what draws the sheet the router now presents, if the present worked.
    private func keepPresentedSheet(_ sheet: AuthSheet) {
        guard let presented = router.presented, presented !== sheetRouter else {
            return
        }
        presentedSheet = sheet
        sheetRouter = presented
        sheetOptions = router.state.presentation.map { router.sheetOptions(for: $0) }
    }

    @ViewBuilder
    private func makeSheetScreen(for sheet: AuthSheet) -> some View {
        switch sheet {
        case .resetPassword:
            makeResetPasswordFlow()
        case .terms:
            factory.makeTerms(onDone: { self.dismissSheet() })
        }
    }

    @ViewBuilder
    private func makeResetPasswordFlow() -> some View {
        if let resetPassword {
            resetPassword.root
        }
    }

    // Continue on a Create account step: the next step, registering the account, or signing in.
    func continueCreatingAccount(after step: CreateAccountStep) {
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
        errorMessage = nil
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
            signedIn(as: account)
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
            try await builder.register()
            showStep(.checkEmail)
        } catch {
            errorMessage = error.message
        }
    }
}

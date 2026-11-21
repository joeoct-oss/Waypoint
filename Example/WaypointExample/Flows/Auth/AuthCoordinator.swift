//
//  AuthCoordinator.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import SwiftUI
import Waypoint
import WaypointCore

// The accounts flow, presented as a sheet when the reader does something that needs an account:
// Sign in at the root, the three steps of Create account pushed above it, Reset password as a sheet
// over Sign in, and the terms as a sheet over Choose a password. The steps share one draft, so
// going back keeps what the reader typed. Signing in and creating an account go through the auth
// service; the flow reports the account, or Cancel, to the account gate that presented it.
//
// The flow runs on Waypoint: `router` is the flow the main tab router presents, the steps are
// `CreateAccountRoute` pushes, and Reset password and the terms are flows this router presents.
// The sheets themselves are still SwiftUI's, bound to the routers, until Waypoint draws them.
//
// Conformances:
// - `Observable` (from `@Observable`), so `AuthFlowView` redraws when a sheet, the error or the
//   busy state changes.
@MainActor
@Observable
final class AuthCoordinator {
    let router: StackRouter
    private let reason: SignInReason
    private let service: any AuthService
    private let onSignedIn: (Account) -> Void
    private let onCancel: () -> Void
    private let draft: SignUpDraft
    // `var` because creating an account keeps it until Check your email reports Verify and continue.
    private var newAccount: Account?
    // `var` because `showResetPassword()` and `showTerms()` set it with the router they present,
    // and `releaseSheet()` clears both once the sheet has slid away, so it still draws meanwhile.
    private(set) var presentedSheet: AuthSheet?
    // `var` for the same reason as `presentedSheet`: the presented sheet's router.
    private(set) var sheetRouter: StackRouter?
    // `var` because a call to the auth service sets it while the call runs.
    private(set) var isWorking: Bool
    // `var` because a failed call to the auth service sets it, and the next call clears it.
    private(set) var errorMessage: String?

    // Whether Reset password or the terms is presented over the flow.
    var isShowingSheet: Bool {
        router.presented != nil
    }

    init(
        router: StackRouter,
        reason: SignInReason,
        service: any AuthService,
        onSignedIn: @escaping (Account) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.router = router
        self.reason = reason
        self.service = service
        self.onSignedIn = onSignedIn
        self.onCancel = onCancel
        draft = SignUpDraft()
        newAccount = nil
        presentedSheet = nil
        sheetRouter = nil
        isWorking = false
        errorMessage = nil
        router.setRootName("Sign in")
        router.register(ResetPasswordRoute.self)
        router.register(TermsRoute.self)
        router.setCoordinator(self)
    }

    func makeSignInFlow() -> some View {
        SignInView(
            reason: reason,
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
            router: router,
            route: nil
        )
    }

    func makeDestination(for route: CreateAccountRoute) -> some View {
        makeCreateAccountFlow(route.step)
            .screenChrome(
                title: route.title,
                kind: nil,
                router: router,
                route: AnyRoute(route)
            )
    }

    @ViewBuilder
    func makeSheetFlow() -> some View {
        if let sheetRouter, let presentedSheet {
            WaypointStack(sheetRouter) {
                makeSheetScreen(for: presentedSheet)
            }
        }
    }

    func showCreateAccount() {
        errorMessage = nil
        router.push(CreateAccountRoute(step: .details))
    }

    func showResetPassword() {
        showSheet(.resetPassword, route: ResetPasswordRoute())
    }

    func showTerms() {
        showSheet(.terms, route: TermsRoute())
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
    }

    private func showSheet<R: Route>(
        _ sheet: AuthSheet,
        route: R
    ) {
        router.present(route, style: .sheet)
        guard let presented = router.presented else {
            return
        }
        presentedSheet = sheet
        sheetRouter = presented
    }

    @ViewBuilder
    private func makeSheetScreen(for sheet: AuthSheet) -> some View {
        switch sheet {
        case .resetPassword:
            makeResetPasswordFlow()
        case .terms:
            makeTermsFlow()
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
        router.push(CreateAccountRoute(step: step))
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

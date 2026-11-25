//
//  CreateAccountBuilder.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import ExampleServices
import ExampleStore
import Observation

// Create account's journey: the draft the reader types across its three steps, each step's screen
// built from that one draft, and the account the auth service registers from it. The accounts
// coordinator holds one builder for the flow, so going back a step keeps every typed value, and
// closing the flow drops it.
//
// Conformances:
// - `Observable` (from `@Observable`), so Check your email redraws once the account is registered.
@Observable
package final class CreateAccountBuilder {
    package let draft: SignUpDraft
    private let service: any AuthService
    // `var` because `register()` keeps the account it registered until the last step finishes.
    package private(set) var account: Account?

    package init(service: any AuthService) {
        self.service = service
        draft = SignUpDraft()
        account = nil
    }

    package func makeStep(
        _ step: CreateAccountStep,
        isWorking: Bool,
        errorMessage: String?,
        onContinue: @escaping () -> Void,
        onShowTerms: @escaping () -> Void
    ) -> CreateAccountStepView {
        CreateAccountStepView(
            step: step,
            draft: draft,
            isWorking: isWorking,
            errorMessage: errorMessage,
            onContinue: onContinue,
            onShowTerms: onShowTerms
        )
    }

    // Registers the account the draft describes, and keeps it.
    @discardableResult
    package func register() async throws(AuthError) -> Account {
        let registered = try await service.register(
            name: draft.name,
            email: draft.email,
            password: draft.password
        )
        account = registered
        return registered
    }
}

//
//  CreateAccountStepView.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import ExampleCatalog
import ExampleDesignSystem
import SwiftUI

// One step of creating an account under the bar's Create account title: the step's own title, its
// fields, and Continue (or Verify and continue on the last step, once the reader has typed the
// 6-digit code from the email; Send a new code says a new one is on its way). The fields write the
// coordinator's draft, so going back keeps what the reader typed. Continue closes the keyboard
// first, so going back never brings it up over Continue. The screen reports Continue and Read the
// terms, and the accounts coordinator decides what comes next.
struct CreateAccountStepView: View {
    let step: CreateAccountStep
    @Bindable var draft: SignUpDraft
    let isWorking: Bool
    let errorMessage: String?
    let onContinue: () -> Void
    let onShowTerms: () -> Void

    // `var` because SwiftUI moves focus between the fields, and Continue clears it.
    @FocusState private var focusedField: Field?
    // `var` because Send a new code sets it, to say the code is on its way.
    @State private var hasSentNewCode = false

    private var canContinue: Bool {
        switch step {
        case .details:
            return !draft.name.isEmpty && !draft.email.isEmpty
        case .password:
            return draft.canContinueFromPassword
        case .checkEmail:
            return draft.hasFullCode
        }
    }

    var body: some View {
        Form {
            fields
            FormErrorSection(message: errorMessage)
        }
        .exampleForm()
        .bottomActionBar { continueButton }
    }

    @ViewBuilder
    private var fields: some View {
        switch step {
        case .details:
            detailFields
        case .password:
            passwordFields
        case .checkEmail:
            checkEmailMessage
        }
    }

    private var detailFields: some View {
        Section {
            TextField("Name", text: $draft.name)
                .textContentType(.name)
                .focused($focusedField, equals: .name)
                .accessibilityIdentifier(Identifiers.signUpName)
            TextField("Email", text: $draft.email)
                .textContentType(.username)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .focused($focusedField, equals: .email)
                .accessibilityIdentifier(Identifiers.signUpEmail)
        } header: {
            stepHeader
        }
    }

    private var passwordFields: some View {
        Section {
            SecureField("Password", text: $draft.password)
                .textContentType(.newPassword)
                .focused($focusedField, equals: .password)
                .accessibilityIdentifier(Identifiers.signUpPassword)
            Toggle("I accept the terms", isOn: $draft.acceptsTerms)
                .accessibilityIdentifier(Identifiers.signUpAcceptTerms)
            Button("Read the terms", action: onShowTerms)
                .accessibilityIdentifier(Identifiers.signUpTerms)
        } header: {
            stepHeader
        }
    }

    private var checkEmailMessage: some View {
        Section {
            Label {
                Text("We sent a 6-digit code to \(draft.email).")
            } icon: {
                Image(systemName: "envelope.badge")
            }
            TextField("6-digit code", text: $draft.code)
                .textContentType(.oneTimeCode)
                .keyboardType(.numberPad)
                .focused($focusedField, equals: .code)
                .accessibilityIdentifier(Identifiers.signUpCode)
            Button("Send a new code", action: sendNewCode)
                .accessibilityIdentifier(Identifiers.signUpNewCode)
            if hasSentNewCode {
                Text("A new code is on its way.")
                    .font(Typography.footnote)
                    .foregroundStyle(Palette.textSecondary.color)
                    .accessibilityIdentifier(Identifiers.signUpCodeSent)
            }
        } header: {
            stepHeader
        }
    }

    private var stepHeader: some View {
        Text(step.title)
            .font(Typography.display)
            .foregroundStyle(Palette.text.color)
            .textCase(nil)
            .padding(.bottom, Spacing.small)
    }

    private var continueButton: some View {
        PrimaryActionButton(
            title: step.actionTitle,
            identifier: Identifiers.signUpContinue,
            action: continueToNextStep
        )
        .disabled(!canContinue || isWorking)
        .padding(Spacing.large)
    }

    private func sendNewCode() {
        draft.code = ""
        hasSentNewCode = true
    }

    private func continueToNextStep() {
        focusedField = nil
        onContinue()
    }
}

extension CreateAccountStepView {
    // The fields that can hold the keyboard's focus.
    //
    // Conformances:
    // - `Hashable`, so `@FocusState` can tell which field has focus.
    private enum Field: Hashable {
        case name
        case email
        case password
        case code
    }
}

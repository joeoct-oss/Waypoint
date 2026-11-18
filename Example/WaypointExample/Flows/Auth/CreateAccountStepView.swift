//
//  CreateAccountStepView.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import SwiftUI

// One step of creating an account under the bar's Create account title: the step's own title, its
// fields, and Continue (or Start shopping on the last step). The fields write the coordinator's
// draft, so going back keeps what the reader typed. Continue closes the keyboard first, so going
// back never brings it up over Continue. The screen reports Continue and Read the terms, and the
// accounts coordinator decides what comes next.
struct CreateAccountStepView: View {
    let step: CreateAccountStep
    @Bindable var draft: SignUpDraft
    let isWorking: Bool
    let errorMessage: String?
    let onContinue: () -> Void
    let onShowTerms: () -> Void

    // `var` because SwiftUI moves focus between the fields, and Continue clears it.
    @FocusState private var focusedField: Field?

    private var canContinue: Bool {
        switch step {
        case .details:
            return !draft.name.isEmpty && !draft.email.isEmpty
        case .password:
            return draft.canContinueFromPassword
        case .checkEmail:
            return true
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
                Text("We sent a link to \(draft.email). Open it any time to confirm your account.")
            } icon: {
                Image(systemName: "envelope.badge")
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
    }
}

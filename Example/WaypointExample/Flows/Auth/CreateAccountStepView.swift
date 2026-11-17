//
//  CreateAccountStepView.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <52625092+JoeOCT91@users.noreply.github.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import SwiftUI

// One step of creating an account under the bar's Create account title: the step's own title, its fields,
// and Continue (or Start shopping on the last step). The
// fields write the coordinator's draft, so going back keeps what the reader typed. The screen reports
// Continue and Read the terms, and the accounts coordinator decides what comes next.
struct CreateAccountStepView: View {
    let step: CreateAccountStep
    @Bindable var draft: SignUpDraft
    let onContinue: () -> Void
    let onShowTerms: () -> Void

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
                .accessibilityIdentifier(Identifiers.signUpName)
            TextField("Email", text: $draft.email)
                .textContentType(.username)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .accessibilityIdentifier(Identifiers.signUpEmail)
        } header: {
            stepHeader
        }
    }

    private var passwordFields: some View {
        Section {
            SecureField("Password", text: $draft.password)
                .textContentType(.newPassword)
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
            action: onContinue
        )
        .disabled(!canContinue)
        .padding(Spacing.large)
    }
}

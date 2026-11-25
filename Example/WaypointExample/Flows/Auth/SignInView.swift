//
//  SignInView.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import ExampleCatalog
import ExampleDesignSystem
import ExampleNavigation
import SwiftUI

// Sign in, the root of the accounts sheet: email and password, Sign in, and ways to create an
// account or reset the password. The screen reports each choice, and the accounts coordinator
// decides where it goes. Cancel closes the sheet and drops the action that asked for an account.
// Sign in closes the keyboard first, so an error and the other ways in stay in view.
package struct SignInView: View {
    package let reason: SignInReason
    package let isWorking: Bool
    package let errorMessage: String?
    package let onSignIn: (String, String) -> Void
    package let onCreateAccount: () -> Void
    package let onForgotPassword: () -> Void
    package let onCancel: () -> Void

    @State private var email = ""
    @State private var password = ""
    // `var` because SwiftUI moves focus between the fields, and Sign in clears it.
    @FocusState private var focusedField: Field?

    private var canSignIn: Bool {
        !email.isEmpty && !password.isEmpty && !isWorking
    }

    package var body: some View {
        Form {
            credentialFields
            FormErrorSection(message: errorMessage)
            otherWays
        }
        .exampleForm()
        .scrollDismissesKeyboard(.interactively)
        .accessibilityIdentifier(Identifiers.signIn)
        .toolbar { cancelItem }
        .bottomActionBar { signInButton }
    }

    private var credentialFields: some View {
        Section {
            TextField("Email", text: $email)
                .textContentType(.username)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .focused($focusedField, equals: .email)
                .accessibilityIdentifier(Identifiers.signInEmail)
            SecureField("Password", text: $password)
                .textContentType(.password)
                .focused($focusedField, equals: .password)
                .accessibilityIdentifier(Identifiers.signInPassword)
        } header: {
            header
        }
    }

    private var otherWays: some View {
        Section {
            Button("Forgot password?", action: onForgotPassword)
                .accessibilityIdentifier(Identifiers.forgotPassword)
            Button("Create an account", action: onCreateAccount)
                .accessibilityIdentifier(Identifiers.signInCreateAccount)
        }
    }

    // The sheet's title, then why it opened.
    private var header: some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            Text("Sign in to continue")
                .font(Typography.display)
                .foregroundStyle(Palette.text.color)
            Text(reason.line)
                .font(Typography.callout)
                .foregroundStyle(Palette.textSecondary.color)
                .accessibilityIdentifier(Identifiers.signInReason)
        }
        .textCase(nil)
        .padding(.bottom, Spacing.small)
    }

    private var cancelItem: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("Cancel", systemImage: "xmark", action: onCancel)
                .accessibilityIdentifier(Identifiers.authCancel)
        }
    }

    private var signInButton: some View {
        PrimaryActionButton(
            title: "Sign in",
            identifier: Identifiers.signInButton,
            action: signIn
        )
        .disabled(!canSignIn)
        .padding(Spacing.large)
    }

    private func signIn() {
        focusedField = nil
        onSignIn(email, password)
    }
}

extension SignInView {
    // The fields that can hold the keyboard's focus.
    //
    // Conformances:
    // - `Hashable`, so `@FocusState` can tell which field has focus.
    private enum Field: Hashable {
        case email
        case password
    }
}

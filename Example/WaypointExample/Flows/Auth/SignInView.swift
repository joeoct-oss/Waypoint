//
//  SignInView.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import SwiftUI

// Sign in, the root of the accounts sheet: email and password, Sign in, and ways to create an
// account or reset the password. The screen reports each choice, and the accounts coordinator
// decides where it goes. Cancel closes the sheet and drops the action that asked for an account.
struct SignInView: View {
    let isWorking: Bool
    let errorMessage: String?
    let onSignIn: (String, String) -> Void
    let onCreateAccount: () -> Void
    let onForgotPassword: () -> Void
    let onCancel: () -> Void

    @State private var email = ""
    @State private var password = ""

    private var canSignIn: Bool {
        !email.isEmpty && !password.isEmpty && !isWorking
    }

    var body: some View {
        Form {
            credentialFields
            FormErrorSection(message: errorMessage)
            otherWays
        }
        .exampleForm()
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
                .accessibilityIdentifier(Identifiers.signInEmail)
            SecureField("Password", text: $password)
                .textContentType(.password)
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

    private var header: some View {
        Text("Sign in to continue")
            .font(Typography.display)
            .foregroundStyle(Palette.text.color)
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
        onSignIn(email, password)
    }
}

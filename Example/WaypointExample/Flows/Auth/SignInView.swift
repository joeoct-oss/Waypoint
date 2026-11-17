//
//  SignInView.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <52625092+JoeOCT91@users.noreply.github.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import SwiftUI

// Sign in: email and password, with a way to reset the password. The screen reports each choice, and the
// accounts coordinator decides where it goes. Any email and password sign in.
struct SignInView: View {
    let onSignIn: () -> Void
    let onForgotPassword: () -> Void

    @State private var email = ""
    @State private var password = ""

    var body: some View {
        Form {
            Section {
                TextField("Email", text: $email)
                    .textContentType(.username)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                SecureField("Password", text: $password)
                    .textContentType(.password)
            } header: {
                header
            }
            Section {
                Button("Forgot password?", action: onForgotPassword)
                    .accessibilityIdentifier(Identifiers.forgotPassword)
            }
        }
        .exampleForm()
        .accessibilityIdentifier(Identifiers.signIn)
        .bottomActionBar { signInButton }
    }

    private var header: some View {
        Text("Welcome back")
            .font(Typography.display)
            .foregroundStyle(Palette.text.color)
            .textCase(nil)
            .padding(.bottom, Spacing.small)
    }

    private var signInButton: some View {
        PrimaryActionButton(
            title: "Sign in",
            identifier: Identifiers.signInButton,
            action: onSignIn
        )
        .padding(Spacing.large)
    }
}

//
//  ForgotPasswordView.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <52625092+JoeOCT91@users.noreply.github.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import SwiftUI

// Reset password: an email field and a button that "sends" the link, then goes back to sign in.
struct ForgotPasswordView: View {
    let onSent: () -> Void

    @State private var email = ""

    var body: some View {
        Form {
            Section {
                TextField("Email", text: $email)
                    .textContentType(.username)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
            } footer: {
                Text("We'll email you a link to choose a new password.")
            }
        }
        .scrollContentBackground(.hidden)
        .safeAreaInset(edge: .bottom) { sendButton }
    }

    private var sendButton: some View {
        PrimaryActionButton(
            title: "Send link",
            identifier: "auth.forgotPassword.submit",
            action: onSent
        )
        .padding(Spacing.large)
    }
}

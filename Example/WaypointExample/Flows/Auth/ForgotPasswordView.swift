//
//  ForgotPasswordView.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import SwiftUI

// Reset password, as a sheet over Sign in: an email field and Send link. Send link reports the
// email to the accounts coordinator, which asks the auth service to send the link, and turns the
// sheet into its Link sent state. Done there (or Cancel before sending) reports to the coordinator,
// which closes the sheet.
struct ForgotPasswordView: View {
    let onSend: (String) -> Void
    let onDone: () -> Void
    let onCancel: () -> Void

    @State private var email = ""
    @State private var isSent = false

    var body: some View {
        NavigationStack {
            content
                .navigationTitle(isSent ? "Link sent" : "Reset password")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { toolbarItems }
        }
        .presentationDetents(ForgotPasswordDetents.all)
    }

    @ViewBuilder
    private var content: some View {
        if isSent {
            sentMessage
        } else {
            emailForm
        }
    }

    private var emailForm: some View {
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
    }

    private var sentMessage: some View {
        ContentUnavailableView(
            "Check your email",
            systemImage: "envelope.badge",
            description: Text("Open the link we sent to choose a new password.")
        )
        .accessibilityIdentifier(Identifiers.resetSent)
    }

    @ToolbarContentBuilder
    private var toolbarItems: some ToolbarContent {
        if isSent {
            ToolbarItem(placement: .confirmationAction) {
                doneButton
            }
        } else {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel", action: onCancel)
            }
            ToolbarItem(placement: .confirmationAction) {
                sendButton
            }
        }
    }

    private var doneButton: some View {
        Button("Done", action: onDone)
            .accessibilityIdentifier(Identifiers.resetDone)
    }

    private var sendButton: some View {
        Button("Send link", action: send)
            .accessibilityIdentifier(Identifiers.resetSend)
    }

    private func send() {
        onSend(email)
        isSent = true
    }
}

// The sizes the Reset password sheet can take: one small size, since both states fit in it.
enum ForgotPasswordDetents {
    static var all: Set<PresentationDetent> {
        [
            .medium,
        ]
    }
}

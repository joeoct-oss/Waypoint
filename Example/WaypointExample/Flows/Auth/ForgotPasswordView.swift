//
//  ForgotPasswordView.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <52625092+JoeOCT91@users.noreply.github.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import SwiftUI

// Reset password, as a sheet over Sign in: an email field and Send link, which closes the sheet.
struct ForgotPasswordView: View {
    let onSent: () -> Void
    let onCancel: () -> Void

    @State private var email = ""

    var body: some View {
        NavigationStack {
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
            .navigationTitle("Reset password")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarItems }
        }
        .presentationDetents(ForgotPasswordDetents.all)
    }

    @ToolbarContentBuilder
    private var toolbarItems: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("Cancel", action: onCancel)
        }
        ToolbarItem(placement: .confirmationAction) {
            Button("Send link", action: onSent)
        }
    }
}

// The sizes the Reset password sheet can take.
enum ForgotPasswordDetents {
    static var all: Set<PresentationDetent> {
        [
            .medium,
        ]
    }
}

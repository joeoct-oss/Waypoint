//
//  CreateAccountView.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <52625092+JoeOCT91@users.noreply.github.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import SwiftUI

// Create account: name, email and password. Creating the account signs the reader in.
struct CreateAccountView: View {
    let onCreate: () -> Void

    @State private var name = ""
    @State private var email = ""
    @State private var password = ""

    var body: some View {
        Form {
            Section {
                TextField("Name", text: $name)
                    .textContentType(.name)
                TextField("Email", text: $email)
                    .textContentType(.username)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                SecureField("Password", text: $password)
                    .textContentType(.newPassword)
            }
        }
        .scrollContentBackground(.hidden)
        .safeAreaInset(edge: .bottom) { createButton }
    }

    private var createButton: some View {
        PrimaryActionButton(
            title: "Create account",
            identifier: "auth.createAccount.submit",
            action: onCreate
        )
        .padding(Spacing.large)
    }
}

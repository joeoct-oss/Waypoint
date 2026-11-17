//
//  CreateAccountStepView.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <52625092+JoeOCT91@users.noreply.github.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import SwiftUI

// One step of creating an account: its fields, and Continue (or Create account on the last step). The
// screen reports Continue, and the accounts coordinator pushes the next step or finishes.
struct CreateAccountStepView: View {
    let step: CreateAccountStep
    let onContinue: () -> Void

    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var likesLamps = true
    @State private var likesPrints = false

    var body: some View {
        Form {
            fields
        }
        .scrollContentBackground(.hidden)
        .safeAreaInset(edge: .bottom) { continueButton }
    }

    @ViewBuilder
    private var fields: some View {
        switch step {
        case .name:
            nameFields
        case .credentials:
            credentialFields
        case .interests:
            interestFields
        }
    }

    private var nameFields: some View {
        Section {
            TextField("Name", text: $name)
                .textContentType(.name)
        }
    }

    private var credentialFields: some View {
        Section {
            TextField("Email", text: $email)
                .textContentType(.username)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
            SecureField("Password", text: $password)
                .textContentType(.newPassword)
        }
    }

    private var interestFields: some View {
        Section {
            Toggle("Lamps and lights", isOn: $likesLamps)
            Toggle("Prints and posters", isOn: $likesPrints)
        }
    }

    private var continueButton: some View {
        PrimaryActionButton(
            title: step.actionTitle,
            identifier: "auth.createAccount.continue",
            action: onContinue
        )
        .padding(Spacing.large)
    }
}

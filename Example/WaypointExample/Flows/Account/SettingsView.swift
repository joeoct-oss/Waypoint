//
//  SettingsView.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import SwiftUI

// Settings (AU-05, AU-06): App (Appearance and Notifications), Developer (the Navigation Lab for
// trying every demo flow, and Clear all data, which asks to confirm next to the button), About (the
// version) and, for a signed-in reader, Sign out. The screen reports each choice to the account
// coordinator.
struct SettingsView: View {
    let isSignedIn: Bool
    let onShowLab: () -> Void
    let onClearAllData: () -> Void
    let onSignOut: () -> Void

    // `var` because the toggle changes it; the sample app keeps it for this screen only.
    @State private var notifies = true
    // `var` because Clear all data sets it to show the confirmation, and the dialog clears it.
    @State private var isConfirmingClear = false

    // The app's version and build, such as `1.0 (42)`, from its bundle.
    private var version: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        return "\(short) (\(build))"
    }

    var body: some View {
        List {
            Section("App") {
                LabeledContent("Appearance", value: "System")
                Toggle("Notifications", isOn: $notifies)
            }
            Section {
                labButton
                clearButton
            } header: {
                Text("Developer")
            } footer: {
                Text("Try every navigation flow in SwiftUI and UIKit, or start over as a fresh install.")
            }
            Section("About") {
                LabeledContent("Version", value: version)
            }
            signOutSection
        }
        .exampleList()
    }

    private var labButton: some View {
        Button(action: onShowLab) {
            Label {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Navigation Lab")
                    Text("Every Waypoint flow, in SwiftUI and UIKit")
                        .font(Typography.footnote)
                        .foregroundStyle(Palette.textTertiary.color)
                }
            } icon: {
                Image(systemName: "flask")
            }
        }
        .foregroundStyle(Palette.text.color)
        .accessibilityIdentifier(Identifiers.labButton)
    }

    @ViewBuilder
    private var signOutSection: some View {
        if isSignedIn {
            Section {
                Button("Sign out", role: .destructive, action: onSignOut)
                    .accessibilityIdentifier(Identifiers.signOut)
            }
        }
    }

    private var clearButton: some View {
        Button("Clear all data", systemImage: "trash", role: .destructive, action: confirmClear)
            .accessibilityIdentifier(Identifiers.clearData)
            .confirmationDialog(
                "Clear all data?",
                isPresented: $isConfirmingClear,
                titleVisibility: .visible
            ) {
                clearActions
            } message: {
                Text("This signs you out and empties your cart and wish list.")
            }
    }

    private var clearActions: some View {
        Button("Clear all data", role: .destructive, action: onClearAllData)
            .accessibilityIdentifier(Identifiers.confirmClearData)
    }

    private func confirmClear() {
        isConfirmingClear = true
    }
}

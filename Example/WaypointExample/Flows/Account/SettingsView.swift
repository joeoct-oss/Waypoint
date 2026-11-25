//
//  SettingsView.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import ExampleCatalog
import ExampleDesignSystem
import SwiftUI

// Settings (AU-05, AU-06): App (Appearance and Notifications), Developer (the Navigation Lab for
// trying every demo flow, and Clear all data, which asks to confirm next to the button), About (the
// version) and, for a signed-in reader, Sign out. Navigation rules (planning #415) shows the
// duplicate push rule, which it can change for testing, and, for a signed-in reader, a button that
// pushes Orders twice in a row to try it. It shows the queued-call limit and how many calls failed
// with no fallback, and tries the two calls the app's fallbacks recover and one no fallback covers.
// The screen reports each choice to the account coordinator.
package struct SettingsView: View {
    private static let rulesTitle = "Navigation rules"
    private static let pushesTwiceTitle = "Allow the same push twice"
    private static let rulesFooter = "By default a second push of the screen already on its way is "
        + "skipped, so Open Orders twice opens it once. Of the last three calls, the first two fail and "
        + "the app's fallbacks recover them; the last one has no fallback, so it counts as not "
        + "recovered. The issue banner and the Lab's event log show each one."

    package let isSignedIn: Bool
    package let onShowLab: () -> Void
    package let onClearAllData: () -> Void
    package let onSignOut: () -> Void
    package let rules: SettingsRules

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

    package var body: some View {
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
            rulesSection
            Section("About") {
                LabeledContent("Version", value: version)
            }
            signOutSection
        }
        .exampleList()
    }

    private var rulesSection: some View {
        Section {
            Toggle(Self.pushesTwiceTitle, isOn: Binding(reading: rules.pushesTwice, writing: rules.onSetPushesTwice))
                .accessibilityIdentifier(Identifiers.duplicatePushRule)
            // Orders needs an account, so a guest doesn't get the button.
            if isSignedIn {
                Button("Open Orders twice", action: rules.onTryPushTwice)
                    .accessibilityIdentifier(Identifiers.tryPushTwice)
            }
            LabeledContent("Queued calls limit", value: rules.queueLimit, format: .number)
                .accessibilityIdentifier(Identifiers.queueLimit)
            LabeledContent("Calls not recovered", value: rules.failureCount, format: .number)
                .accessibilityIdentifier(Identifiers.failureCount)
            Button("Go back to Orders", action: rules.onTryMissingPop)
                .accessibilityIdentifier(Identifiers.tryMissingPop)
            Button("Open sign in twice", action: rules.onTryPresentTwice)
                .accessibilityIdentifier(Identifiers.tryPresentTwice)
            Button("Close the Account tab", action: rules.onTryUnrecovered)
                .accessibilityIdentifier(Identifiers.tryUnrecovered)
        } header: {
            Text(Self.rulesTitle)
        } footer: {
            Text(Self.rulesFooter)
        }
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

// The four calls Settings' navigation rules section tries, which the account coordinator makes.
package struct SettingsTries {
    package let pushTwice: () -> Void
    package let missingPop: () -> Void
    package let presentTwice: () -> Void
    package let unrecovered: () -> Void
}

// What Settings shows of the app's navigation rules, and what it reports.
package struct SettingsRules {
    // Whether the duplicate push rule is `.allow`, so a second push of the same route goes ahead.
    package let pushesTwice: Bool
    package let queueLimit: Int
    package let failureCount: Int
    package let onSetPushesTwice: (Bool) -> Void
    package let onTryPushTwice: () -> Void
    package let onTryMissingPop: () -> Void
    package let onTryPresentTwice: () -> Void
    package let onTryUnrecovered: () -> Void
}

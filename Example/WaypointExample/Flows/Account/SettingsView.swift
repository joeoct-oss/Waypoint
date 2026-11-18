//
//  SettingsView.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import SwiftUI

// Settings: app preferences, and under Developer the Navigation Lab for trying every demo flow and
// Clear all data, which asks to confirm next to the button and then reports to the account
// coordinator.
struct SettingsView: View {
    let onShowLab: () -> Void
    let onClearAllData: () -> Void

    @State private var notifies = true
    @State private var isConfirmingClear = false

    var body: some View {
        List {
            Section {
                Toggle("Order updates", isOn: $notifies)
            }
            Section {
                Button(action: onShowLab) {
                    Label("Navigation Lab", systemImage: "flask")
                }
                .accessibilityIdentifier(Identifiers.labButton)
                clearButton
            } header: {
                Text("Developer")
            } footer: {
                Text("Try every navigation flow in SwiftUI and UIKit, or start over as a fresh install.")
            }
        }
        .exampleList()
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

//
//  SettingsView.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <52625092+JoeOCT91@users.noreply.github.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import SwiftUI

// Settings: app preferences, and the Navigation Lab under Developer for trying every demo flow.
struct SettingsView: View {
    let onShowLab: () -> Void

    @State private var notifies = true

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
            } header: {
                Text("Developer")
            } footer: {
                Text("Try every navigation flow in SwiftUI and UIKit.")
            }
        }
        .exampleList()
    }
}

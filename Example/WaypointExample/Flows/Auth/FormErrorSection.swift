//
//  FormErrorSection.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import ExampleCatalog
import ExampleDesignSystem
import SwiftUI

// The reason a form's last request failed, such as a wrong password, shown as its own section in
// the design system's error color.
struct FormErrorSection: View {
    let message: String?

    var body: some View {
        if let message {
            makeSection(message)
        }
    }

    private func makeSection(_ message: String) -> some View {
        Section {
            Label(message, systemImage: "exclamationmark.circle")
                .foregroundStyle(Palette.error.color)
                .accessibilityIdentifier(Identifiers.authError)
        }
    }
}

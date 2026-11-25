//
//  TermsView.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import ExampleCatalog
import ExampleDesignSystem
import SwiftUI

// The shop's terms, as a sheet over Choose a password, with Done. Closing it leaves the password
// step as the reader left it.
package struct TermsView: View {
    package let onDone: () -> Void

    package var body: some View {
        ScrollView {
            Text(TermsText.body)
                .font(Typography.body)
                .foregroundStyle(Palette.text.color)
                .padding(Spacing.large)
        }
        .navigationTitle("Terms")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { doneItem }
        .accessibilityIdentifier(Identifiers.terms)
    }

    private var doneItem: some ToolbarContent {
        ToolbarItem(placement: .confirmationAction) {
            Button("Done", action: onDone)
                .accessibilityIdentifier(Identifiers.termsDone)
        }
    }
}

// The words of the shop's terms.
package enum TermsText {
    package static let body = """
        Orbit Shop is an example app. Nothing you buy here is real, nothing is charged, and nothing you type \
        leaves this device.
        """
}

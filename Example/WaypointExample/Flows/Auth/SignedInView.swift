//
//  SignedInView.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import SwiftUI

// Signed in, the last step of the accounts flow when it opened over another sheet: who is signed
// in, what carried on, and Done, which the screen only reports. The coordinator that opened the
// sheets closes them all in one change. Back is hidden, because the reader is signed in now.
struct SignedInView: View {
    let name: String
    let resumedAction: String?
    let onDone: () -> Void

    var body: some View {
        VStack(spacing: Spacing.medium) {
            Image(systemName: "checkmark.circle.fill")
                .font(Typography.display)
                .foregroundStyle(Palette.success.color)
                .accessibilityHidden(true)
            Text("Signed in as \(name)")
                .font(Typography.headline)
                .foregroundStyle(Palette.text.color)
            if let resumedAction {
                Text(resumedAction)
                    .foregroundStyle(Palette.textSecondary.color)
            }
            PrimaryActionButton(
                title: "Done",
                identifier: Identifiers.signedInDone,
                action: onDone
            )
        }
        .padding(Spacing.large)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .navigationBarBackButtonHidden()
        // Contains its children, so Done keeps its own identifier.
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(Identifiers.signedIn)
    }
}

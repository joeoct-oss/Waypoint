//
//  PrimaryActionButton.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <52625092+JoeOCT91@users.noreply.github.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import SwiftUI

// The main action of a screen, such as Sign in or Place order: a system prominent capsule button in the
// brand color, with text that passes 4.5:1 on it in both appearances.
struct PrimaryActionButton: View {
    let title: String
    let identifier: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(Typography.headline)
                .foregroundStyle(Palette.onBrand.color)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .tint(Palette.brand.color)
        .buttonBorderShape(.capsule)
        .controlSize(.large)
        .accessibilityIdentifier(identifier)
    }
}

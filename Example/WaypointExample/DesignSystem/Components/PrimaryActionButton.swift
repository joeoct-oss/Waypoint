//
//  PrimaryActionButton.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import SwiftUI

// The main action of a screen, such as Sign in or Place order: a system prominent capsule button in
// the brand color, with text that passes 4.5:1 on it in both appearances.
package struct PrimaryActionButton: View {
    package let title: String
    package let identifier: String
    package let action: () -> Void

    package init(
        title: String,
        identifier: String,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.identifier = identifier
        self.action = action
    }

    package var body: some View {
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

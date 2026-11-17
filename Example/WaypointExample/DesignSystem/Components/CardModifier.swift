//
//  CardModifier.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <52625092+JoeOCT91@users.noreply.github.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import SwiftUI

// Draws content on a card: the surface color, a hairline border and the card radius.
//
// Conformances:
// - `ViewModifier`, so any view can become a card with `.card()`.
struct CardModifier: ViewModifier {
    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: Radius.card)
    }

    private var border: some View {
        shape.strokeBorder(Palette.line.color)
    }

    func body(content: Content) -> some View {
        content
            .background(Palette.surface.color, in: shape)
            .overlay(border)
    }
}

extension View {
    func card() -> some View {
        modifier(CardModifier())
    }
}

//
//  KindButtonStyle.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <52625092+JoeOCT91@users.noreply.github.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import SwiftUI

// The secondary button that launches a flow of one kind, with its title in the kind's color.
//
// Conformances:
// - `ButtonStyle`, so each kind's button keeps the system's tap handling and accessibility.
struct KindButtonStyle: ButtonStyle {
    let kind: FlowKind

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: Radius.field)
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Typography.callout.weight(.semibold))
            .foregroundStyle(kind.tint.color)
            .frame(maxWidth: .infinity, minHeight: Size.minimumTouchTarget)
            .background(Palette.surface.color, in: shape)
            .overlay(shape.strokeBorder(Palette.line.color))
            .opacity(configuration.isPressed ? 0.6 : 1)
    }
}

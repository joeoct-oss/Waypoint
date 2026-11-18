//
//  CheckoutStepHeader.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import SwiftUI

// The top of each checkout step: a bar of three segments filled up to this step, "Step n of 3"
// with the step's name, and the step's heading.
struct CheckoutStepHeader: View {
    static let stepCount = 3

    let number: Int
    let name: String
    let heading: String

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.medium) {
            progress
            Text("Step \(number) of \(Self.stepCount) · \(name)")
                .font(Typography.footnote)
                .foregroundStyle(Palette.textTertiary.color)
            Text(heading)
                .font(Typography.display)
                .foregroundStyle(Palette.text.color)
                .accessibilityAddTraits(.isHeader)
        }
    }

    private var progress: some View {
        HStack(spacing: 6) {
            ForEach(1...Self.stepCount, id: \.self) { step in
                Capsule()
                    .fill(step <= number ? Palette.accent.color : Palette.line.color)
                    .frame(height: 4)
            }
        }
        .accessibilityHidden(true)
    }
}

// The card behind a group of rows, as checkout and Account draw it: the surface color with a
// hairline border.
//
// Conformances:
// - `ViewModifier`, so `rowsCard()` can apply it to any group of rows.
struct RowsCardBackground: ViewModifier {
    private var border: some View {
        RoundedRectangle(cornerRadius: Radius.card)
            .strokeBorder(Palette.line.color)
    }

    func body(content: Content) -> some View {
        content
            .padding(.horizontal, Spacing.large)
            .background(Palette.surface.color, in: RoundedRectangle(cornerRadius: Radius.card))
            .overlay(border)
    }
}

// A hairline between two rows of a card.
struct RowDivider: View {
    var body: some View {
        Divider()
            .overlay(Palette.line.color)
    }
}

extension View {
    func rowsCard() -> some View {
        modifier(RowsCardBackground())
    }
}

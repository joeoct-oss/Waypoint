//
//  RowsCard.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import SwiftUI

// The card behind a group of rows, as checkout and Account draw it: the surface color with a
// hairline border.
//
// Conformances:
// - `ViewModifier`, so `rowsCard()` can apply it to any group of rows.
package struct RowsCardBackground: ViewModifier {
    private var border: some View {
        RoundedRectangle(cornerRadius: Radius.card)
            .strokeBorder(Palette.line.color)
    }

    package func body(content: Content) -> some View {
        content
            .padding(.horizontal, Spacing.large)
            .background(Palette.surface.color, in: RoundedRectangle(cornerRadius: Radius.card))
            .overlay(border)
    }
}

// A hairline between two rows of a card.
package struct RowDivider: View {
    package init() { }

    package var body: some View {
        Divider()
            .overlay(Palette.line.color)
    }
}

extension View {
    package func rowsCard() -> some View {
        modifier(RowsCardBackground())
    }
}

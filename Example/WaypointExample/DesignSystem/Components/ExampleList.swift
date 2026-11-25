//
//  ExampleList.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import SwiftUI

// The list and form looks every screen shares: system inset-grouped rows on the design system's
// background, with the layout grid's 16 pt margin on both sides. Rows stay in the content layer and
// scroll under the system bars, and `exampleRow()` puts a row on the design system's surface, so in
// dark mode it takes the surface's navy tint instead of the system's grey.
extension View {
    package func exampleList() -> some View {
        listStyle(.insetGrouped)
            .exampleForm()
    }

    package func exampleRow() -> some View {
        listRowBackground(Palette.surface.color)
    }

    package func exampleForm() -> some View {
        scrollContentBackground(.hidden)
            .contentMargins(.horizontal, Spacing.large, for: .scrollContent)
            .background(Palette.background.color)
    }
}

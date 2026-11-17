//
//  ExampleList.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <52625092+JoeOCT91@users.noreply.github.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import SwiftUI

// The list look every list screen shares: system inset-grouped rows on the design system's background.
// Rows stay in the content layer and scroll under the system bars.
extension View {
    func exampleList() -> some View {
        listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Palette.background.color)
    }
}

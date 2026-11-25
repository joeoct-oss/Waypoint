//
//  FilterView.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import ExampleCatalog
import SwiftUI

// The filter sheet: a price range and a sort order, applied with one button. Its sizes come from
// the router (`AppSheets.filters`): it opens at medium and grows to large.
struct FilterView: View {
    let onApply: () -> Void

    @State private var maximumPrice = 100.0
    @State private var sortsByPrice = false

    var body: some View {
        Form {
            Section("Price") {
                Slider(value: $maximumPrice, in: 10...100)
                Text("Up to \(Int(maximumPrice)) USD")
            }
            Section {
                Toggle("Sort by price", isOn: $sortsByPrice)
            }
        }
        .navigationTitle("Filter")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { applyItem }
    }

    private var applyItem: some ToolbarContent {
        ToolbarItem(placement: .confirmationAction) {
            Button("Apply", action: onApply)
                .accessibilityIdentifier(Identifiers.filterApply)
        }
    }
}

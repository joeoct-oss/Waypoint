//
//  SearchView.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import ExampleCatalog
import ExampleDesignSystem
import ExampleStore
import SwiftUI

// Search (MA-01): a search field at the top of the list. It isn't the system's `searchable`, which
// shows no field for a screen inside the `TabView` that the one stack around the tabs holds. Before
// the reader types, it offers recent searches and the shop's categories, and a tap on either fills
// the field. Once there is a query, it lists the products whose name or category holds every word
// of it, under a count. A tapped result goes to the view model, which pushes the product.
struct SearchView: View {
    private static let recentSearches = [
        "lamp",
        "mug",
        "star print",
    ]

    let model: SearchModel

    @State private var query = ""

    private var results: [Product] {
        model.results(for: query)
    }

    private var resultCount: String {
        results.count == 1 ? "1 result" : "\(results.count) results"
    }

    var body: some View {
        List {
            searchField
            if query.isEmpty {
                suggestions
            } else {
                resultsSection
            }
        }
        .exampleList()
    }

    private var searchField: some View {
        Section {
            HStack(spacing: Spacing.small) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(Palette.textTertiary.color)
                TextField("Products, categories", text: $query)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.search)
                    .accessibilityIdentifier(Identifiers.searchField)
            }
        }
    }

    @ViewBuilder
    private var suggestions: some View {
        Section("Recent") {
            ForEach(Self.recentSearches, id: \.self) { term in
                makeSuggestion(term, symbolName: "clock.arrow.circlepath")
                    .accessibilityIdentifier(Identifiers.recentSearch(term))
            }
        }
        Section("Categories") {
            ForEach(model.categories, id: \.self) { category in
                makeSuggestion(category, symbolName: "square.grid.2x2")
            }
        }
    }

    private var resultsSection: some View {
        Section {
            ForEach(results) { product in
                ProductRow(product: product) { model.select(product) }
            }
        } header: {
            Text(resultCount)
                .accessibilityIdentifier(Identifiers.searchResultCount)
        }
    }

    private func makeSuggestion(_ term: String, symbolName: String) -> some View {
        Button {
            query = term
        } label: {
            Label(term, systemImage: symbolName)
                .foregroundStyle(Palette.text.color)
        }
    }
}

//
//  SearchView.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import SwiftUI

// Search: the system search field, always shown under the bar, over the products whose name matches.
struct SearchView: View {
    let onSelect: (Product) -> Void

    @State private var query = ""

    private var results: [Product] {
        guard !query.isEmpty else {
            return Product.all
        }
        return Product.all.filter { $0.name.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        List(results) { product in
            ProductRow(product: product) { onSelect(product) }
        }
        .exampleList()
        .searchable(
            text: $query,
            placement: SearchFieldPlacement.navigationBarDrawer(displayMode: .always),
            prompt: "Products"
        )
    }
}

//
//  CollectionView.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import ExampleCatalog
import ExampleDesignSystem
import ExampleStore
import SwiftUI

// A collection from Shop's banner: its tagline over its products as rows. The screen reports the
// product the reader picks.
package struct CollectionView: View {
    package let collection: ProductCollection
    package let onSelect: (Product) -> Void

    package var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.large) {
                Text(collection.tagline)
                    .font(Typography.callout)
                    .foregroundStyle(Palette.textTertiary.color)
                ProductRowCard(products: collection.products, onSelect: onSelect)
            }
            .padding(Spacing.large)
        }
        .background(Palette.background.color)
        .accessibilityIdentifier(Identifiers.collectionScreen)
    }
}

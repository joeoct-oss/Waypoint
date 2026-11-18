//
//  CollectionView.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import SwiftUI

// A collection from Shop's banner: its tagline over its products as rows. The screen reports the
// product the reader picks.
struct CollectionView: View {
    let collection: ProductCollection
    let onSelect: (Product) -> Void

    var body: some View {
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

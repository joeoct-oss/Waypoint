//
//  OrdersView.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import ExampleCatalog
import ExampleDesignSystem
import ExampleStore
import SwiftUI

// Orders (MA-03): the reader's past orders, each with its number, status line and total. The screen
// reports the order the reader picks.
struct OrdersView: View {
    let onSelect: (Order) -> Void

    var body: some View {
        List(Order.all) { order in
            Button {
                onSelect(order)
            } label: {
                OrderRow(order: order)
            }
            .foregroundStyle(Palette.text.color)
            .accessibilityIdentifier(Identifiers.order(id: order.id))
            .exampleRow()
        }
        .exampleList()
    }
}

// One order in the list: "Order 1042" over its status line, its total, and a chevron.
struct OrderRow: View {
    let order: Order

    var body: some View {
        HStack(spacing: Spacing.medium) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Order \(order.id)")
                    .font(Typography.headline)
                Text(order.statusLine)
                    .font(Typography.footnote)
                    .foregroundStyle(Palette.textTertiary.color)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Text(order.total, format: .currency(code: "USD").precision(.fractionLength(0)))
                .font(Typography.callout.weight(.semibold))
            Image(systemName: "chevron.right")
                .font(Typography.footnote.weight(.semibold))
                .foregroundStyle(Palette.textTertiary.color)
                .accessibilityHidden(true)
        }
        .padding(.vertical, Spacing.small)
        .contentShape(Rectangle())
    }
}

// One order: a Placed, Shipped, Delivered timeline, then what was in it. The bar's title already
// names the order.
struct OrderDetailView: View {
    let order: Order

    var body: some View {
        List {
            Section {
                timeline
            }
            Section("Items") {
                ForEach(order.products) { product in
                    ProductRowContent(product: product, detail: "Qty 1")
                }
            }
        }
        .exampleList()
    }

    private var timeline: some View {
        HStack(spacing: Spacing.small) {
            ForEach(OrderStage.allCases, id: \.self) { stage in
                makeStep(stage)
            }
        }
        .padding(.vertical, Spacing.small)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(Identifiers.orderTimeline)
    }

    private func makeStep(_ stage: OrderStage) -> some View {
        let isReached = stage <= order.stage
        return VStack(spacing: Spacing.extraSmall) {
            Image(systemName: isReached ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(isReached ? Palette.success.color : Palette.textTertiary.color)
                .accessibilityHidden(true)
            Text(stage.title)
                .font(Typography.footnote)
                .foregroundStyle(isReached ? Palette.text.color : Palette.textTertiary.color)
        }
        .frame(maxWidth: .infinity)
    }
}

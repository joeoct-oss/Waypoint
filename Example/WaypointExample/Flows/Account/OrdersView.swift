//
//  OrdersView.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import SwiftUI

// Orders: the reader's past orders. The screen reports the order the reader picks.
struct OrdersView: View {
    let onSelect: (Order) -> Void

    var body: some View {
        List(Order.all) { order in
            Button {
                onSelect(order)
            } label: {
                LabeledContent(order.productName, value: order.status)
            }
            .foregroundStyle(Palette.text.color)
            .accessibilityIdentifier(Identifiers.order(id: order.id))
            .exampleRow()
        }
        .exampleList()
    }
}

// One order: what was bought and where it is. The bar's title already names the order.
struct OrderDetailView: View {
    let order: Order

    var body: some View {
        List {
            LabeledContent("Product", value: order.productName)
            LabeledContent("Status", value: order.status)
        }
        .exampleList()
    }
}

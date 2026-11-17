//
//  OrdersView.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <52625092+JoeOCT91@users.noreply.github.com>.
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
        }
        .exampleList()
    }
}

// One order: what was bought and where it is.
struct OrderDetailView: View {
    let order: Order

    var body: some View {
        List {
            LabeledContent("Order", value: "\(order.id)")
            LabeledContent("Product", value: order.productName)
            LabeledContent("Status", value: order.status)
        }
        .exampleList()
    }
}

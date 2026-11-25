//
//  CheckoutReviewView.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import ExampleCatalog
import ExampleDesignSystem
import ExampleStore
import SwiftUI

// Checkout's last step: where the order goes, how it is paid, and the total, with Place order at
// the bottom. The screen reports Place order.
package struct CheckoutReviewView: View {
    package let products: [Product]
    package let address: Address?
    package let onPlaceOrder: () -> Void

    package var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.large) {
                CheckoutStepHeader(
                    number: 3,
                    name: "Review",
                    heading: "Review"
                )
                details
                total
            }
            .padding(Spacing.large)
        }
        .background(Palette.background.color)
        .bottomActionBar { placeOrderButton }
    }

    private var details: some View {
        VStack(spacing: 0) {
            if let address {
                makeAddressRow(for: address)
                RowDivider()
            }
            paymentRow
        }
        .rowsCard()
    }

    private var paymentRow: some View {
        HStack(spacing: Spacing.medium) {
            Image(systemName: "creditcard")
                .frame(width: Size.radio)
                .accessibilityHidden(true)
            PaymentCardLabel()
        }
        .padding(.vertical, Spacing.medium)
    }

    private var total: some View {
        HStack {
            Text("Total")
            Spacer()
            Text(Product.total(of: products), format: .currency(code: "USD"))
        }
        .font(Typography.headline)
        .foregroundStyle(Palette.text.color)
        .padding(.vertical, Spacing.medium)
        .rowsCard()
    }

    private var placeOrderButton: some View {
        PrimaryActionButton(
            title: "Place order",
            identifier: Identifiers.placeOrder,
            action: onPlaceOrder
        )
        .disabled(products.isEmpty)
        .padding(Spacing.large)
    }

    private func makeAddressRow(for address: Address) -> some View {
        HStack(spacing: Spacing.medium) {
            Image(systemName: "mappin.and.ellipse")
                .frame(width: Size.radio)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(address.street)
                    .font(Typography.headline)
                Text(address.cityLine)
                    .font(Typography.footnote)
                    .foregroundStyle(Palette.textTertiary.color)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .foregroundStyle(Palette.text.color)
        .padding(.vertical, Spacing.medium)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(Identifiers.reviewAddress)
    }
}

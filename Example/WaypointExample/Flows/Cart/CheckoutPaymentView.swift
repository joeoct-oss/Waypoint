//
//  CheckoutPaymentView.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import SwiftUI

// Checkout's second step: the saved card, chosen, with Continue to review at the bottom. The example
// app has one card, so there is nothing else to pick. The screen reports Continue.
struct CheckoutPaymentView: View {
    let onContinue: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.large) {
                CheckoutStepHeader(
                    number: 2,
                    name: "Payment",
                    heading: "Pay with"
                )
                card
            }
            .padding(Spacing.large)
        }
        .background(Palette.background.color)
        .bottomActionBar { continueButton }
    }

    private var card: some View {
        HStack(spacing: Spacing.medium) {
            RadioMark(isSelected: true)
            PaymentCardLabel()
        }
        .padding(.vertical, Spacing.medium)
        .rowsCard()
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isSelected)
    }

    private var continueButton: some View {
        PrimaryActionButton(
            title: "Continue to review",
            identifier: Identifiers.continueToReview,
            action: onContinue
        )
        .padding(Spacing.large)
    }
}

// The example app's one saved card: its last digits and expiry.
struct PaymentCardLabel: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Card ending 4242")
                .font(Typography.headline)
                .foregroundStyle(Palette.text.color)
            Text("Expires 08/29")
                .font(Typography.footnote)
                .foregroundStyle(Palette.textTertiary.color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

//
//  CheckoutAddressView.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import ExampleAddresses
import ExampleCatalog
import ExampleDesignSystem
import ExampleStore
import SwiftUI

// Checkout's first step: the saved addresses as a choice, one of them chosen, and Add a new address
// below them, with Continue to payment at the bottom and Close in the bar. When an address was just
// added, a toast says so over the bottom. The screen reports each choice.
struct CheckoutAddressView: View {
    let addresses: [Address]
    let selectedID: String?
    let savedNotice: Address?
    let onSelect: (Address) -> Void
    let onAddAddress: () -> Void
    let onContinue: () -> Void
    let onClose: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.large) {
                CheckoutStepHeader(
                    number: 1,
                    name: "Address",
                    heading: "Deliver to"
                )
                choices
            }
            .padding(Spacing.large)
        }
        .background(Palette.background.color)
        .accessibilityIdentifier(Identifiers.checkoutAddress)
        .toolbar { closeItem }
        .bottomActionBar { bottomBar }
    }

    private var choices: some View {
        VStack(spacing: 0) {
            ForEach(addresses) { address in
                makeChoice(for: address)
                RowDivider()
            }
            addAddressButton
        }
        .rowsCard()
    }

    private var addAddressButton: some View {
        Button(action: onAddAddress) {
            Label("Add a new address", systemImage: "plus")
                .font(Typography.headline)
                .foregroundStyle(Palette.brand.color)
                .frame(maxWidth: .infinity, minHeight: Size.minimumTouchTarget, alignment: .leading)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(Identifiers.addAddress)
    }

    private var bottomBar: some View {
        VStack(spacing: Spacing.medium) {
            if let savedNotice {
                SavedAddressToast(address: savedNotice)
            }
            PrimaryActionButton(
                title: "Continue to payment",
                identifier: Identifiers.continueToPayment,
                action: onContinue
            )
            .disabled(selectedID == nil)
        }
        .padding(Spacing.large)
    }

    private var closeItem: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("Close", systemImage: "xmark", action: onClose)
                .accessibilityIdentifier(Identifiers.closeCheckout)
        }
    }

    private func makeChoice(for address: Address) -> some View {
        let isSelected = address.id == selectedID
        return Button {
            onSelect(address)
        } label: {
            AddressRow(address: address, style: .choice(isSelected: isSelected))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(Identifiers.address(label: address.label))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// The dark toast that says a new address was saved and chosen, with the result the form handed back
// in Waypoint's log style.
struct SavedAddressToast: View {
    let address: Address

    var body: some View {
        HStack(spacing: Spacing.medium) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(ToastColor.success)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text("Address saved")
                    .font(Typography.callout.weight(.semibold))
                Text("AddAddress .saved(\(address.label)) · selected")
                    .font(Typography.code)
                    .foregroundStyle(ToastColor.detail)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .foregroundStyle(ToastColor.text)
        .padding(Spacing.medium)
        .background(ToastColor.background, in: RoundedRectangle(cornerRadius: Radius.card))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(Identifiers.addressSaved)
    }
}

// The toast's colors. The toast is always dark, so it reads over any screen in both appearances.
enum ToastColor {
    static let background = Color(artHex: 0x151A3D)
    static let text = Color(artHex: 0xEEF0FF)
    static let detail = Color(artHex: 0xB4BADB)
    static let success = Color(artHex: 0x4FD1A1)
}

//
//  AddressesView.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import SwiftUI

// Account, Addresses: the reader's saved addresses, with Add a new address below them. The screen
// reports Add a new address.
struct AddressesView: View {
    let addresses: [Address]
    let onAddAddress: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(addresses) { address in
                    AddressRow(address: address, style: .saved)
                        .accessibilityElement(children: .combine)
                        .accessibilityIdentifier(Identifiers.address(label: address.label))
                    RowDivider()
                }
                addAddressButton
            }
            .rowsCard()
            .padding(Spacing.large)
        }
        .background(Palette.background.color)
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
}

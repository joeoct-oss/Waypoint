//
//  AddressRow.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import ExampleDesignSystem
import ExampleStore
import SwiftUI

// One address: its label over its street and city line. In checkout it starts with a radio circle,
// filled when the address is the one chosen; in Account it starts with a pin.
package struct AddressRow: View {
    package let address: Address
    package let style: AddressRowStyle

    package init(
        address: Address,
        style: AddressRowStyle
    ) {
        self.address = address
        self.style = style
    }

    package var body: some View {
        HStack(spacing: Spacing.medium) {
            marker
            VStack(alignment: .leading, spacing: 2) {
                Text(address.label)
                    .font(Typography.headline)
                    .foregroundStyle(Palette.text.color)
                Text("\(address.street)\n\(address.cityLine)")
                    .font(Typography.footnote)
                    .foregroundStyle(Palette.textSecondary.color)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, Spacing.small)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var marker: some View {
        switch style {
        case .choice(let isSelected):
            RadioMark(isSelected: isSelected)
        case .saved:
            savedMark
        }
    }

    private var savedMark: some View {
        Image(systemName: "mappin.and.ellipse")
            .font(Typography.headline)
            .foregroundStyle(Palette.brand.color)
            .frame(width: Size.radio)
            .accessibilityHidden(true)
    }
}

// How an address row starts: a radio circle for a choice, or a pin for a saved address.
package enum AddressRowStyle {
    case choice(isSelected: Bool)
    case saved
}

// A radio circle, filled with the brand color when chosen.
package struct RadioMark: View {
    package let isSelected: Bool

    package init(
        isSelected: Bool
    ) {
        self.isSelected = isSelected
    }

    package var body: some View {
        Circle()
            .strokeBorder(isSelected ? Palette.brand.color : Palette.line.color, lineWidth: 2)
            .overlay(fill)
            .frame(width: Size.radio, height: Size.radio)
            .accessibilityHidden(true)
    }

    @ViewBuilder
    private var fill: some View {
        if isSelected {
            Circle()
                .fill(Palette.brand.color)
                .padding(6)
        }
    }
}

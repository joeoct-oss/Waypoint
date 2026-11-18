//
//  AddAddressView.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import SwiftUI

// The new-address form: Label, Street, City and Postcode, then Save address once every field has
// text. In checkout it also asks whether to save the address for next time; in Account, saving is
// the point, so it doesn't ask. The screen reports the address and the choice.
struct AddAddressView: View {
    let asksToKeep: Bool
    let onSave: (Address, Bool) -> Void

    @State private var label = ""
    @State private var street = ""
    @State private var city = ""
    @State private var postcode = ""
    @State private var keepsForNextTime = true

    private var isComplete: Bool {
        let fields = [
            label,
            street,
            city,
            postcode,
        ]
        return fields.allSatisfy { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
    }

    var body: some View {
        Form {
            Section {
                TextField("Label", text: $label, prompt: Text("Home, Work, Studio"))
                    .accessibilityIdentifier(Identifiers.addressLabel)
                TextField("Street", text: $street)
                    .textContentType(.fullStreetAddress)
                    .accessibilityIdentifier(Identifiers.addressStreet)
                TextField("City", text: $city)
                    .textContentType(.addressCity)
                    .accessibilityIdentifier(Identifiers.addressCity)
                TextField("Postcode", text: $postcode)
                    .textContentType(.postalCode)
                    .accessibilityIdentifier(Identifiers.addressPostcode)
            }
            keepSection
        }
        .exampleForm()
        .bottomActionBar { saveButton }
    }

    @ViewBuilder
    private var keepSection: some View {
        if asksToKeep {
            Section {
                Toggle("Save for next time", isOn: $keepsForNextTime)
                    .tint(Palette.success.color)
                    .accessibilityIdentifier(Identifiers.addressKeep)
            }
        }
    }

    private var saveButton: some View {
        PrimaryActionButton(
            title: "Save address",
            identifier: Identifiers.saveAddress,
            action: save
        )
        .disabled(!isComplete)
        .padding(Spacing.large)
    }

    private func save() {
        let address = Address.new(
            label: label,
            street: street,
            city: city,
            postcode: postcode
        )
        onSave(address, keepsForNextTime || !asksToKeep)
    }
}

//
//  Address.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import Foundation

// A delivery address the reader saved, or added for one order. The local store keeps the saved
// ones, starting from two samples.
//
// Conformances:
// - `Codable`, so the local store can save the reader's addresses.
// - `Hashable`, so an address can sit in a navigation path and lists can tell addresses apart.
// - `Identifiable`, so lists can show addresses without naming an id key path.
package nonisolated struct Address: Codable, Hashable, Identifiable {
    package static let samples = [
        Address(
            id: "home",
            label: "Home",
            street: "12 Orbit Way",
            city: "Springfield",
            postcode: "40210"
        ),
        Address(
            id: "work",
            label: "Work",
            street: "4 Comet Court, floor 3",
            city: "Springfield",
            postcode: "40118"
        ),
    ]

    package let id: String
    package let label: String
    package let street: String
    package let city: String
    package let postcode: String

    // The second line under the street, as the canvas writes it: the city, then the postcode.
    package var cityLine: String {
        "\(city) \(postcode)"
    }

    // Makes a new address with an id of its own, from what the reader typed in the form.
    package static func new(
        label: String,
        street: String,
        city: String,
        postcode: String
    ) -> Address {
        Address(
            id: UUID().uuidString,
            label: label,
            street: street,
            city: city,
            postcode: postcode
        )
    }
}

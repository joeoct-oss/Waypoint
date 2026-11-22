//
//  Account.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//


// A signed-in reader. The mock auth service makes one when the reader signs in or creates an
// account, and the local store keeps it between launches.
//
// Conformances:
// - `Codable`, so the local store can save the signed-in account.
// - `Hashable`, so screens can compare accounts.
nonisolated struct Account: Codable, Hashable {
    static let sample = Account(
        name: "Nova Reader",
        email: "nova@example.com"
    )

    let name: String
    let email: String
}

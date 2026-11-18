//
//  SignUpDraft.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import Observation

// What the reader has typed while creating an account. The accounts coordinator keeps one draft for the
// whole journey, so going back a step and forward again keeps every typed value.
//
// Conformances:
// - `Observable` (from `@Observable`), so each step redraws as its fields change.
@MainActor
@Observable
final class SignUpDraft {
    // `var` because the details step's fields write it.
    var name: String
    // `var` because the details step's fields write it.
    var email: String
    // `var` because the password step's field writes it.
    var password: String
    // `var` because the password step's toggle writes it.
    var acceptsTerms: Bool

    var canContinueFromPassword: Bool {
        acceptsTerms && !password.isEmpty
    }

    init() {
        name = ""
        email = ""
        password = ""
        acceptsTerms = false
    }
}

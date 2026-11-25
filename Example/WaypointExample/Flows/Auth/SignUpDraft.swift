//
//  SignUpDraft.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import Observation

// What the reader has typed while creating an account. The accounts coordinator keeps one draft for
// the whole journey, so going back a step and forward again keeps every typed value.
//
// Conformances:
// - `Observable` (from `@Observable`), so each step redraws as its fields change.
@Observable
package final class SignUpDraft {
    package static let codeLength = 6

    // `var` because the details step's fields write it.
    package var name: String
    // `var` because the details step's fields write it.
    package var email: String
    // `var` because the password step's field writes it.
    package var password: String
    // `var` because the password step's toggle writes it.
    package var acceptsTerms: Bool
    // `var` because the check-your-email step's field writes it.
    package var code: String

    package var canContinueFromPassword: Bool {
        acceptsTerms && !password.isEmpty
    }

    // The code from the email is six digits.
    package var hasFullCode: Bool {
        code.count == Self.codeLength && code.allSatisfy(\.isNumber)
    }

    package init() {
        name = ""
        email = ""
        password = ""
        acceptsTerms = false
        code = ""
    }
}

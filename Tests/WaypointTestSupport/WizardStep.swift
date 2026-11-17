//
//  WizardStep.swift
//  Waypoint
//
//  Created by Yousef Mohamed <52625092+JoeOCT91@users.noreply.github.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import WaypointCore

/// A shared test route for a closed group of screens registered as one type: the allowed small enum from decision 0003.
///
/// Conformances:
/// - `String` raw value: gives each case a readable name in saved state.
/// - `Route`, so it can be pushed, presented and saved in tests.
/// - `CaseIterable`, so tests can walk every step.
package enum WizardStep: String, Route, CaseIterable {
    /// Enter an address.
    case address
    /// Choose a payment method.
    case payment
    /// Review and confirm.
    case review
}

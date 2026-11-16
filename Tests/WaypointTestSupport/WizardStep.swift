//
//  WizardStep.swift
//  Waypoint
//
//  Created by Yousef Mohamed <52625092+JoeOCT91@users.noreply.github.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

/// A shared test route for a closed group of screens registered as one type: the allowed small enum from decision 0003.
package enum WizardStep: String, Hashable, Sendable, Codable, CaseIterable {
    /// Enter an address.
    case address
    /// Choose a payment method.
    case payment
    /// Review and confirm.
    case review
}

//
//  AuthRoute.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import WaypointCore

// A step of Create account, pushed on the accounts flow's router above Sign in.
//
// Conformances:
// - `TrackableScreen`, a `Route` the journey log names by its step.
package struct CreateAccountRoute: TrackableScreen {
    package static let screenName = "Create account"
    package static let publicLogFields: Set<String> = [
        "step"
    ]

    package let step: CreateAccountStep

    package init(
        step: CreateAccountStep
    ) {
        self.step = step
    }

    package var title: String {
        "Create account"
    }

    package var screenDisplayName: String? {
        step.title
    }
}

// Signed in, pushed on the accounts flow's router above Sign in when the flow opened over another
// sheet, so its Done can close both sheets.
//
// Conformances:
// - `TrackableScreen`, a `Route` the journey log names "Signed in".
package struct SignedInRoute: TrackableScreen {
    package static let screenName = "Signed in"
}

// The terms, presented as a sheet over Choose a password by the accounts flow's router.
//
// Conformances:
// - `TrackableScreen`, a `Route` the journey log names "Terms".
package struct TermsRoute: TrackableScreen {
    package static let screenName = "Terms"
}

// The three pushed steps of creating an account.
//
// Conformances:
// - `CaseIterable`, so each step knows the one after it and the trail can name the steps before it.
// - `Hashable` and `Codable`, so a step can sit in a `CreateAccountRoute`.
package nonisolated enum CreateAccountStep: CaseIterable, Hashable, Codable {
    case details
    case password
    case checkEmail

    package var title: String {
        switch self {
        case .details:
            return "Your details"
        case .password:
            return "Choose a password"
        case .checkEmail:
            return "Check your email"
        }
    }

    package var actionTitle: String {
        switch self {
        case .details, .password:
            return "Continue"
        case .checkEmail:
            return "Verify and continue"
        }
    }

    package var next: CreateAccountStep? {
        let steps = Self.allCases
        guard let index = steps.firstIndex(of: self), index + 1 < steps.count else {
            return nil
        }
        return steps[index + 1]
    }
}

// A sheet the accounts flow can present: Reset password over Sign in, or the terms over Choose a
// password.
//
// The sheet's router draws one of these until the sheet has slid away.
package enum AuthSheet {
    case resetPassword
    case terms
}

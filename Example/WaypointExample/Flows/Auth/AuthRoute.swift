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
struct CreateAccountRoute: TrackableScreen {
    static let screenName = "Create account"
    static let publicLogFields: Set<String> = [
        "step",
    ]

    let step: CreateAccountStep

    var title: String {
        "Create account"
    }

    var screenDisplayName: String? {
        step.title
    }
}

// Signed in, pushed on the accounts flow's router above Sign in when the flow opened over another
// sheet, so its Done can close both sheets.
//
// Conformances:
// - `TrackableScreen`, a `Route` the journey log names "Signed in".
struct SignedInRoute: TrackableScreen {
    static let screenName = "Signed in"
}

// The terms, presented as a sheet over Choose a password by the accounts flow's router.
//
// Conformances:
// - `TrackableScreen`, a `Route` the journey log names "Terms".
struct TermsRoute: TrackableScreen {
    static let screenName = "Terms"
}

// The three pushed steps of creating an account.
//
// Conformances:
// - `CaseIterable`, so each step knows the one after it and the trail can name the steps before it.
// - `Hashable` and `Codable`, so a step can sit in a `CreateAccountRoute`.
nonisolated enum CreateAccountStep: CaseIterable, Hashable, Codable {
    case details
    case password
    case checkEmail

    var title: String {
        switch self {
        case .details:
            return "Your details"
        case .password:
            return "Choose a password"
        case .checkEmail:
            return "Check your email"
        }
    }

    var actionTitle: String {
        switch self {
        case .details, .password:
            return "Continue"
        case .checkEmail:
            return "Verify and continue"
        }
    }

    var next: CreateAccountStep? {
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
enum AuthSheet {
    case resetPassword
    case terms
}

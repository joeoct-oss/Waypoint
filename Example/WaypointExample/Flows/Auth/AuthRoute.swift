//
//  AuthRoute.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import WaypointCore

// Sign in, the root of the accounts flow the main tab router presents as a sheet.
//
// Conformances:
// - `TrackableScreen`, a `Route` the journey log names "Sign in".
struct SignInRoute: TrackableScreen {
    static let screenName = "Sign in"
}

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

    var trail: [String] {
        AuthTrail.signIn + step.trail
    }

    var screenDisplayName: String? {
        step.title
    }
}

// Reset password, presented as a sheet over Sign in by the accounts flow's router.
//
// Conformances:
// - `TrackableScreen`, a `Route` the journey log names "Reset password".
struct ResetPasswordRoute: TrackableScreen {
    static let screenName = "Reset password"
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
enum CreateAccountStep: CaseIterable, Hashable, Codable {
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
            return "Start shopping"
        }
    }

    var next: CreateAccountStep? {
        let steps = Self.allCases
        guard let index = steps.firstIndex(of: self), index + 1 < steps.count else {
            return nil
        }
        return steps[index + 1]
    }

    var trail: [String] {
        let steps = Self.allCases.prefix { $0 != self }
        return steps.map(\.trailName) + [trailName]
    }

    private var trailName: String {
        switch self {
        case .details:
            return "details"
        case .password:
            return "password"
        case .checkEmail:
            return "check email"
        }
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

// The route trail at the root of the accounts flow.
enum AuthTrail {
    static let signIn = [
        "sign in",
    ]
}

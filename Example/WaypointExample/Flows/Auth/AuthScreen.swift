//
//  AuthScreen.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

// A screen the accounts flow can push above Welcome.
//
// Conformances:
// - `Hashable`, so `NavigationStack` can keep screens in its path and tell them apart.
enum AuthScreen: Hashable {
    case signIn
    case createAccount(CreateAccountStep)

    var title: String {
        switch self {
        case .signIn:
            return "Sign in"
        case .createAccount:
            return "Create account"
        }
    }

    var trail: [String] {
        switch self {
        case .signIn:
            return AuthTrail.welcome + ["sign in"]
        case .createAccount(let step):
            return AuthTrail.welcome + step.trail
        }
    }
}

// The three pushed steps of creating an account.
//
// Conformances:
// - `CaseIterable`, so each step knows the one after it and the trail can name the steps before it.
// - `Hashable`, so a step can sit in the accounts flow's path.
enum CreateAccountStep: CaseIterable, Hashable {
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
// Conformances:
// - `Identifiable`, so `.sheet(item:)` can tell one sheet from the next.
enum AuthSheet: Identifiable {
    case resetPassword
    case terms

    var id: Self {
        self
    }
}

// The route trail at the root of the accounts flow.
enum AuthTrail {
    static let welcome = [
        "welcome",
    ]
}

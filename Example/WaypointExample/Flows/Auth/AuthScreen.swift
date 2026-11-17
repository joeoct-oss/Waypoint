//
//  AuthScreen.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <52625092+JoeOCT91@users.noreply.github.com>.
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
        case .createAccount(let step):
            return step.title
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
    case name
    case credentials
    case interests

    var title: String {
        switch self {
        case .name:
            return "Your name"
        case .credentials:
            return "Email and password"
        case .interests:
            return "What you like"
        }
    }

    var actionTitle: String {
        switch self {
        case .name, .credentials:
            return "Continue"
        case .interests:
            return "Create account"
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
        case .name:
            return "name"
        case .credentials:
            return "credentials"
        case .interests:
            return "interests"
        }
    }
}

// The route trail at the root of the accounts flow.
enum AuthTrail {
    static let welcome = [
        "welcome",
    ]
}

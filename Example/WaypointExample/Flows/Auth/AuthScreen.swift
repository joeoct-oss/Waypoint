//
//  AuthScreen.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <52625092+JoeOCT91@users.noreply.github.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

// A screen the sign-in flow can push above sign in.
//
// Conformances:
// - `Hashable`, so `NavigationStack` can keep screens in its path and tell them apart.
enum AuthScreen: Hashable {
    case createAccount
    case forgotPassword
}

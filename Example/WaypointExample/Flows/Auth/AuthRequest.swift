//
//  AuthRequest.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

// Why the accounts flow opened, and where signing in leaves it: with `signedInStep`, signing in
// keeps the flow open on Signed in instead of finishing it.
struct AuthRequest {
    let reason: SignInReason
    let signedInStep: SignedInStep?
}

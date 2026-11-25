//
//  AuthForm.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import ExampleServices
import Observation

// What Sign in and Create account's steps show of the call to the auth service: whether a call is
// running, and the message of the last one that failed. The accounts flow runs each call through
// it and clears the message when the reader moves on.
//
// Conformances:
// - `Observable` (from `@Observable`), so the form redraws when a call starts, ends or fails.
@Observable
package final class AuthForm {
    // `var` because `run(_:)` sets it while a call runs.
    package private(set) var isWorking: Bool
    // `var` because a failed call sets it, and `clearError()` clears it.
    package private(set) var errorMessage: String?

    package init() {
        isWorking = false
        errorMessage = nil
    }

    package func clearError() {
        errorMessage = nil
    }

    // Runs one call to the auth service: the form is busy while it runs, and a failure shows its
    // message.
    package func run(_ call: () async throws(AuthError) -> Void) async {
        isWorking = true
        defer {
            isWorking = false
        }
        do {
            try await call()
        } catch {
            errorMessage = error.message
        }
    }
}

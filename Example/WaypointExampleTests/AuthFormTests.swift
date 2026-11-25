//
//  AuthFormTests.swift
//  WaypointExampleTests
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import ExampleServices
import Testing
@testable import WaypointExample

// What Sign in and Create account show of a call to the auth service (planning #462): a failed
// call shows its message and the form isn't busy once the call ends, and the reader moving on
// clears the message.
struct AuthFormTests {
    @Test("A failed call shows its message until it is cleared")
    func failedCallShowsItsMessageUntilCleared() async {
        let form = AuthForm()

        await form.run { () async throws(AuthError) in
            throw AuthError.wrongPassword
        }
        let shown = form.errorMessage
        let busyAfterCall = form.isWorking
        form.clearError()

        #expect(shown == AuthError.wrongPassword.message)
        #expect(!busyAfterCall)
        #expect(form.errorMessage == nil)
    }
}

//
//  ResetPasswordCoordinator.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import ExampleServices
import SwiftUI
import Waypoint

// Reset password, the child flow the accounts flow starts as a sheet over Sign in (planning #313).
// Waypoint makes its router and joins it to the accounts flow's tree when the sheet opens. Send
// link asks the auth service to send the link. Done finishes the flow with the email the link went
// to, and Cancel or a swipe down ends it, which the accounts flow gets as `.cancelled`.
//
// The sheet itself is still SwiftUI's, drawn by the accounts flow, until Waypoint draws presented
// flows.
//
// Conformances:
// - `FlowCoordinator`, so the accounts flow starts it with `present(_:style:onFinish:)` and gets
//   its result.
package final class ResetPasswordCoordinator: FlowCoordinator {
    // The email the reset link went to.
    package typealias Output = String

    private let factory: AuthFactory
    private let service: any AuthService
    // `var` because Send link keeps the email the link went to, for Done to finish with. Only
    // `sendLink(to:)` changes it.
    private var sentTo: String?

    // The journey's name for the flow's only screen.
    package var rootName: String {
        "Reset password"
    }

    package var root: some View {
        factory.makeForgotPassword(
            onSend: { self.sendLink(to: $0) },
            onDone: { self.done() },
            onCancel: { self.cancel() }
        )
    }

    // `AuthFactory` makes it, hands it the auth service and builds its screen.
    package init(factory: AuthFactory) {
        self.factory = factory
        service = factory.dependencies.service
        sentTo = nil
    }

    package func sendLink(to email: String) {
        sentTo = email
        Task {
            await service.sendResetLink(to: email)
        }
    }

    // Finishes with the email the link went to, or ends the flow when none was sent.
    package func done() {
        guard let sentTo else {
            cancel()
            return
        }
        finish(with: sentTo)
    }

    package func cancel() {
        router.dismissFlow()
    }
}

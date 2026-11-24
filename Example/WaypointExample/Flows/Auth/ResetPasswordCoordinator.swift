//
//  ResetPasswordCoordinator.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import SwiftUI
import Waypoint

// Reset password, the child flow the accounts flow starts as a sheet over Sign in (#59). Waypoint
// makes its router and joins it to the accounts flow's tree when the sheet opens. Send link asks
// the auth service to send the link. Done finishes the flow with the email the link went to, and
// Cancel or a swipe down ends it, which the accounts flow gets as `.cancelled`.
//
// The sheet itself is still SwiftUI's, drawn by the accounts flow, until Waypoint draws presented
// flows.
//
// Conformances:
// - `FlowCoordinator`, so the accounts flow starts it with `present(_:style:onFinish:)` and gets
//   its result.
final class ResetPasswordCoordinator: FlowCoordinator {
    // The email the reset link went to.
    typealias Output = String

    private let service: any AuthService
    // `var` because Send link keeps the email the link went to, for Done to finish with. Only
    // `sendLink(to:)` changes it.
    private var sentTo: String?

    // The journey's name for the flow's only screen.
    var rootName: String {
        "Reset password"
    }

    var root: some View {
        ForgotPasswordView(
            onSend: { self.sendLink(to: $0) },
            onDone: { self.done() },
            onCancel: { self.cancel() }
        )
    }

    init(service: any AuthService) {
        self.service = service
        sentTo = nil
    }


    func sendLink(to email: String) {
        sentTo = email
        Task {
            await service.sendResetLink(to: email)
        }
    }

    // Finishes with the email the link went to, or ends the flow when none was sent.
    func done() {
        guard let sentTo else {
            cancel()
            return
        }
        finish(with: sentTo)
    }

    func cancel() {
        router.dismissFlow()
    }
}

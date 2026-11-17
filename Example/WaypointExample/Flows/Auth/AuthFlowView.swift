//
//  AuthFlowView.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <52625092+JoeOCT91@users.noreply.github.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import SwiftUI

// Draws the sign-in flow's stack from its coordinator.
struct AuthFlowView: View {
    let auth: AuthCoordinator

    var body: some View {
        NavigationStack(path: Binding(reading: auth.path, writing: auth.syncPath)) {
            auth.makeSignInFlow()
                .navigationDestination(for: AuthScreen.self) { auth.makeDestination(for: $0) }
        }
    }
}

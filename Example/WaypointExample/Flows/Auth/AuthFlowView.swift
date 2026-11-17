//
//  AuthFlowView.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <52625092+JoeOCT91@users.noreply.github.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import SwiftUI

// Draws the accounts flow's stack and its sheets from their coordinator.
struct AuthFlowView: View {
    let auth: AuthCoordinator

    var body: some View {
        NavigationStack(path: Binding(reading: auth.path, writing: auth.syncPath)) {
            auth.makeWelcomeFlow()
                .navigationDestination(for: AuthScreen.self) { auth.makeDestination(for: $0) }
        }
        .sheet(item: Binding(reading: auth.presentedSheet, writing: auth.syncSheet)) {
            auth.makeSheetFlow(for: $0)
        }
    }
}

//
//  AuthFlowView.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import SwiftUI

// Draws the accounts flow's stack, inside the sheet the account gate presents, and the flow's own
// sheets from their coordinator.
struct AuthFlowView: View {
    let auth: AuthCoordinator

    var body: some View {
        NavigationStack(path: Binding(reading: auth.path, writing: auth.syncPath)) {
            auth.makeSignInFlow()
                .navigationDestination(for: AuthScreen.self) { auth.makeDestination(for: $0) }
        }
        .sheet(item: Binding(reading: auth.presentedSheet, writing: auth.syncSheet)) {
            auth.makeSheetFlow(for: $0)
        }
    }
}

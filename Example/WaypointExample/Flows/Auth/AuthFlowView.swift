//
//  AuthFlowView.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import SwiftUI
import Waypoint

struct AuthFlowView: View {
    let auth: AuthCoordinator

    var body: some View {
        WaypointStack(auth.router) {
            auth.makeSignInFlow()
                .destination(CreateAccountRoute.self) { auth.makeDestination(for: $0) }
                .destination(SignedInRoute.self) { _ in auth.makeSignedInFlow() }
        }
        .sheet(
            isPresented: Binding(reading: auth.isShowingSheet, writing: auth.syncSheet),
            onDismiss: auth.releaseSheet
        ) {
            auth.makeSheetFlow()
        }
    }
}

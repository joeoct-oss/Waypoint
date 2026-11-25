//
//  AuthFlowView.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import ExampleDesignSystem
import SwiftUI
import Waypoint

// The accounts flow, drawn by its coordinator, with Reset password or the terms as a sheet over it.
package struct AuthFlowView: View {
    package let auth: AuthCoordinator

    package init(
        auth: AuthCoordinator
    ) {
        self.auth = auth
    }

    package var body: some View {
        auth.view
            .sheet(
                isPresented: Binding(reading: auth.isShowingSheet, writing: auth.syncSheet),
                onDismiss: auth.releaseSheet
            ) {
                auth.makeSheetFlow()
            }
    }
}

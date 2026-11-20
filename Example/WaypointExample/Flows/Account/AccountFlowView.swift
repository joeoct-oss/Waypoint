//
//  AccountFlowView.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import SwiftUI
import Waypoint

// Draws the account tab's router with `WaypointStack`, and the Lab's view and view-model demos full
// screen over it. Pushed screens hide the tab bar, as Shop's and Search's do.
struct AccountFlowView: View {
    let account: AccountCoordinator

    var body: some View {
        WaypointStack(account.router) {
            account.makeAccountFlow()
                .destination(AccountRoute.self) { account.makeDestination(for: $0) }
        }
        .tabBarOnPushedScreens(.hidden)
        .fullScreenCover(
            item: Binding(reading: account.labDemos.presentedDemo, writing: account.labDemos.syncDemo),
            onDismiss: account.labDemos.releaseDemo
        ) {
            account.labDemos.makeDemoFlow(for: $0)
        }
    }
}

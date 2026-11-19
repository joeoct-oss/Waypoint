//
//  AccountFlowView.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import SwiftUI

// Draws the account stack from its coordinator, and the Lab's view and view-model demos full screen
// over it. The account stack is still a plain SwiftUI stack, so it hides the tab bar on its pushed
// screens itself, as a Waypoint stack does with `tabBarOnPushedScreens(.hidden)`.
struct AccountFlowView: View {
    let account: AccountCoordinator

    var body: some View {
        NavigationStack(path: Binding(reading: account.path, writing: account.syncPath)) {
            account.makeAccountFlow()
                .navigationDestination(for: AccountScreen.self) { screen in
                    account.makeDestination(for: screen)
                        .toolbar(.hidden, for: .tabBar)
                }
        }
        .fullScreenCover(
            item: Binding(reading: account.labDemos.presentedDemo, writing: account.labDemos.syncDemo),
            onDismiss: account.labDemos.releaseDemo
        ) {
            account.labDemos.makeDemoFlow(for: $0)
        }
    }
}

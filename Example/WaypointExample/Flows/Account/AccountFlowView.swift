//
//  AccountFlowView.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import SwiftUI

// Draws the account stack from its coordinator.
struct AccountFlowView: View {
    let account: AccountCoordinator

    var body: some View {
        NavigationStack(path: Binding(reading: account.path, writing: account.syncPath)) {
            account.makeAccountFlow()
                .navigationDestination(for: AccountScreen.self) { account.makeDestination(for: $0) }
        }
    }
}

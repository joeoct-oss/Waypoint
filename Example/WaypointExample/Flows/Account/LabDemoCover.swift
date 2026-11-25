//
//  LabDemoCover.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import ExampleDesignSystem
import SwiftUI
import Waypoint

// The Lab's view and view-model demos, full screen. `MainTabView` gives it to the stack around the
// tabs, since the Lab is pushed and a cover on the tab's root doesn't show under a pushed screen.
//
// Conformances:
// - `ViewModifier`, so `MainTabView` gives it to the stack.
struct LabDemoCover: ViewModifier {
    let account: AccountCoordinator

    func body(content: Content) -> some View {
        content.fullScreenCover(
            item: Binding(reading: account.labDemos.presentedDemo, writing: account.labDemos.syncDemo),
            onDismiss: account.labDemos.releaseDemo
        ) {
            account.labDemos.makeDemoFlow(for: $0)
        }
    }
}

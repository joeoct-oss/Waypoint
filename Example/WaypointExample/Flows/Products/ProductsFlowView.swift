//
//  ProductsFlowView.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import SwiftUI
import Waypoint

// Draws Shop's or Search's root screen from its coordinator; the main tabs show the newest
// navigation issue over it. The screens it pushes go on the one stack around the tabs, which
// `MainTabView` draws, so they cover the tab bar.
struct ProductsFlowView: View {
    let products: ProductsCoordinator

    var body: some View {
        products.makeRootFlow()
            .task { await products.playLaunchSteps() }
    }
}

// Shop's or Search's sheets. `MainTabView` gives it to the stack around the tabs, since a sheet on
// the tab's root doesn't show while a pushed screen covers the root.
//
// Conformances:
// - `ViewModifier`, so `MainTabView` gives it to the stack.
struct ProductsSheet: ViewModifier {
    let products: ProductsCoordinator

    func body(content: Content) -> some View {
        content.sheet(
            isPresented: Binding(reading: products.isShowingSheet, writing: products.syncSheet),
            onDismiss: products.releaseSheet
        ) {
            products.makeSheetFlow()
        }
    }
}

//
//  BottomActionBar.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import SwiftUI

extension View {
    // Puts a screen's main action, such as Add to cart, in a bar at the bottom. From iOS 26 it is a
    // system safe-area bar, so content scrolls under it with the system's edge effect; earlier
    // systems inset the content above it.
    @ViewBuilder
    package func bottomActionBar(@ViewBuilder _ makeBar: () -> some View) -> some View {
        if #available(iOS 26.0, *) {
            safeAreaBar(edge: .bottom, content: makeBar)
        } else {
            safeAreaInset(edge: .bottom, content: makeBar)
        }
    }
}

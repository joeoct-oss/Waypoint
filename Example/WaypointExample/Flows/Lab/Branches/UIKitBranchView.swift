//
//  UIKitBranchView.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import ExampleCatalog
import SwiftUI

// Hosts the UIKit branch's view controller in the app's SwiftUI stack.
//
// Conformances:
// - `UIViewControllerRepresentable`, so SwiftUI can push the UIKit branch like any other screen.
struct UIKitBranchView: UIViewControllerRepresentable {
    let onSelect: (FlowEntry) -> Void

    func makeUIViewController(context: Context) -> UIKitBranchViewController {
        UIKitBranchViewController(onSelect: onSelect)
    }

    func updateUIViewController(
        _ controller: UIKitBranchViewController,
        context: Context
    ) { }
}

//
//  SwiftUIBranchView.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import ExampleCatalog
import ExampleDesignSystem
import SwiftUI

// The SwiftUI branch: the five flows, each launchable as a SwiftUI flow or a UIKit flow. The screen
// reports the entry the reader picks, and the app coordinator opens it.
package struct SwiftUIBranchView: View {
    package let onSelect: (FlowEntry) -> Void

    package var body: some View {
        List {
            ForEach(ExampleFlow.allCases, id: \.self) { flow in
                FlowRow(
                    branch: .swiftUI,
                    flow: flow,
                    onSelect: onSelect
                )
            }
        }
        .exampleList()
    }
}

//
//  KindButton.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import ExampleCatalog
import SwiftUI

// The button that launches a flow of one kind: a system bordered button in the kind's color, so it
// keeps the platform's shape, press feedback and accessibility on every iOS version.
package struct KindButton: View {
    package let kind: FlowKind
    package let onSelect: () -> Void

    package init(
        kind: FlowKind,
        onSelect: @escaping () -> Void
    ) {
        self.kind = kind
        self.onSelect = onSelect
    }

    package var body: some View {
        Button(action: onSelect) {
            Text(kind.buttonTitle)
                .font(Typography.callout.weight(.semibold))
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .buttonBorderShape(.capsule)
        .controlSize(.large)
        .tint(kind.tint.color)
    }
}

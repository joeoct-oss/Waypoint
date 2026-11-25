//
//  CheckoutStepHeader.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import ExampleDesignSystem
import SwiftUI

// The top of each checkout step: a bar of three segments filled up to this step, "Step n of 3"
// with the step's name, and the step's heading.
package struct CheckoutStepHeader: View {
    package static let stepCount = 3

    package let number: Int
    package let name: String
    package let heading: String

    package var body: some View {
        VStack(alignment: .leading, spacing: Spacing.medium) {
            progress
            Text("Step \(number) of \(Self.stepCount) · \(name)")
                .font(Typography.footnote)
                .foregroundStyle(Palette.textTertiary.color)
            Text(heading)
                .font(Typography.display)
                .foregroundStyle(Palette.text.color)
                .accessibilityAddTraits(.isHeader)
        }
    }

    private var progress: some View {
        HStack(spacing: 6) {
            ForEach(1...Self.stepCount, id: \.self) { step in
                Capsule()
                    .fill(step <= number ? Palette.accent.color : Palette.line.color)
                    .frame(height: 4)
            }
        }
        .accessibilityHidden(true)
    }
}

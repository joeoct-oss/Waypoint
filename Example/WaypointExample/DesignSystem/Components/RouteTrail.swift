//
//  RouteTrail.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <52625092+JoeOCT91@users.noreply.github.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import SwiftUI

// The thin strip under the navigation bar that shows the current path: a dot for each screen below, and
// the Nova arrow for the screen you are on.
struct RouteTrail: View {
    let steps: [String]

    var body: some View {
        HStack(spacing: Spacing.small) {
            ForEach(steps.indices, id: \.self) { index in
                step(at: index)
            }
            Spacer(minLength: 0)
        }
        .font(Typography.code)
        .lineLimit(1)
        .padding(.horizontal, Spacing.medium)
        .frame(minHeight: Size.trailHeight)
        .background(Palette.brandSubtle.color, in: Capsule())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    private var accessibilityText: String {
        "Route trail: " + steps.joined(separator: ", ")
    }

    private var connector: some View {
        Rectangle()
            .fill(Palette.brand.color.opacity(0.55))
            .frame(width: 14, height: 2)
    }

    @ViewBuilder
    private func step(at index: Int) -> some View {
        if index > 0 {
            connector
        }
        if index == steps.count - 1 {
            currentStep(steps[index])
        } else {
            earlierStep(steps[index])
        }
    }

    private func earlierStep(_ name: String) -> some View {
        HStack(spacing: Spacing.extraSmall) {
            Circle()
                .fill(Palette.textSecondary.color)
                .frame(width: 6, height: 6)
            Text(name)
        }
        .foregroundStyle(Palette.textSecondary.color)
    }

    private func currentStep(_ name: String) -> some View {
        HStack(spacing: Spacing.extraSmall) {
            Image(systemName: "location.north.fill")
                .imageScale(.small)
                .rotationEffect(.degrees(90))
            Text(name)
                .fontWeight(.semibold)
        }
        .foregroundStyle(Palette.accent.color)
    }
}

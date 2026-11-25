//
//  IssueBanner.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import ExampleCatalog
import ExampleDesignSystem
import ExampleServices
import SwiftUI

// The newest navigation issue, in a banner at the bottom of every tab. It appears only when
// Waypoint logs an issue at `.error` or above: a call a fallback recovered, a call that failed, or
// a system link a UI test draws. Its accessibility value names the build configuration, so a test
// can tell the issue was logged in a release build.
struct IssueBanner: View {
    let issues: IssueLog

    var body: some View {
        if let text = issues.latest {
            Label(text, systemImage: "exclamationmark.triangle.fill")
                .font(Typography.footnote)
                .foregroundStyle(Palette.text.color)
                .lineLimit(4)
                .padding(Spacing.medium)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: Radius.card))
                .padding(Spacing.medium)
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier(Identifiers.navigationIssue)
                .accessibilityValue(BuildConfiguration.name)
                // Only shows, so a tap reaches the screen under it.
                .allowsHitTesting(false)
        }
    }
}

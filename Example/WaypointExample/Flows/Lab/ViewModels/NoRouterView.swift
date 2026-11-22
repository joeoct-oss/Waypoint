//
//  NoRouterView.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import SwiftUI
import Waypoint

// VM-03: a view that uses `@StackNavigation`, shown where no Waypoint stack is above it (full
// screen in a plain SwiftUI stack, over the account stack). The view still draws. Its push does
// nothing and returns `.failed` with a `noRouterInScope` issue, which names the wrapper, its file
// and line, and the fix, and is logged as a fault. In debug builds the screen shows that issue
// under the view.
struct NoRouterView: View {
    // `var` because a tap on Open reviews keeps what the push returned, to show it.
    @State private var failure: NavigationFailure?

    var body: some View {
        List {
            Section {
                ReviewsPreview(onResult: { failure = $0.failure })
            }
            issueSection
        }
        .exampleList()
    }

    @ViewBuilder
    private var issueSection: some View {
        #if DEBUG
            if let failure {
                Section("Debug build only") {
                    MissingRouterNote(failure: failure)
                }
            }
        #endif
    }
}

// A small reviews view that navigates on its own with `@StackNavigation`. It reports what its push
// returned.
struct ReviewsPreview: View {
    let onResult: (NavigationOutcome) -> Void

    @StackNavigation private var navigation

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.medium) {
            Text("Reviews")
                .font(Typography.headline)
            Text("4.8 out of 5, from 212 reviews.")
                .font(Typography.footnote)
                .foregroundStyle(Palette.textSecondary.color)
            Button("Open reviews") {
                onResult(navigation.push(LabReviewsRoute()))
            }
            .accessibilityIdentifier(Identifiers.labOpenReviews)
        }
        .padding(.vertical, Spacing.small)
    }
}

// What the failed push said: its issue, the call site, and the issue's message with the fix.
struct MissingRouterNote: View {
    let failure: NavigationFailure

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            Label(failure.issue.description, systemImage: "exclamationmark.triangle.fill")
                .font(Typography.callout.weight(.semibold))
                .foregroundStyle(Palette.error.color)
            Text(failure.issue.message)
                .font(Typography.code)
                .foregroundStyle(Palette.text.color)
        }
        .padding(.vertical, Spacing.small)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(Identifiers.labMissingRouter)
    }
}

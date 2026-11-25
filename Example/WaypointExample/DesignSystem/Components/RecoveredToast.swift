//
//  RecoveredToast.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import ExampleCatalog
import SwiftUI

// The dark toast a recovered call shows in debug builds (design decision 3): what was missing on
// the first line, and the outcome's one-line description, such as
// `recovered routeNotInPath by=popToRoot`, in code type below it. It is amber, never red, because
// the call worked.
package struct RecoveredToast: View {
    package let content: RecoveredToastContent

    package init(
        content: RecoveredToastContent
    ) {
        self.content = content
    }

    package var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.medium) {
            Image(systemName: "arrow.uturn.backward.circle.fill")
                .foregroundStyle(Palette.toastAmber.color)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: Spacing.extraSmall) {
                Text(content.title)
                    .font(Typography.callout.weight(.semibold))
                    .foregroundStyle(Palette.onToast.color)
                Text(content.outcome)
                    .font(Typography.code)
                    .foregroundStyle(Palette.toastAmber.color)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(Spacing.medium)
        .background(Palette.toast.color, in: RoundedRectangle(cornerRadius: Radius.card))
        .padding(Spacing.large)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(Identifiers.recoveredToast)
    }
}

// What a recovered toast says: a short title, and the outcome's description.
//
// Conformances:
// - `Equatable`, so the toast animates in and out when its content changes.
package struct RecoveredToastContent: Equatable {
    package let title: String
    package let outcome: String

    package init(
        title: String,
        outcome: String
    ) {
        self.title = title
        self.outcome = outcome
    }
}

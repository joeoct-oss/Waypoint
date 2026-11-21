//
//  NoticeToast.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import SwiftUI

// A short notice over the tabs, such as "Signed in as Nova" with the action that carries on, or
// "Signed out". It sits on the system material and goes by itself. `noticeOverlay(_:)` shows it at
// the top of a screen: the tabs, and checkout, whose full-screen cover would hide the tabs' one.
struct NoticeToast: View {
    let notice: Notice

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(notice.title)
                .font(Typography.callout.weight(.semibold))
                .foregroundStyle(Palette.text.color)
            if let detail = notice.detail {
                Text(detail)
                    .font(Typography.footnote)
                    .foregroundStyle(Palette.textSecondary.color)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.medium)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: Radius.card))
        .padding(.horizontal, Spacing.large)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(Identifiers.notice)
    }
}

extension View {
    func noticeOverlay(_ notice: Notice?) -> some View {
        overlay(alignment: .top) {
            if let notice {
                // Taps pass through, so the toast never blocks Back or the bar's buttons under it.
                NoticeToast(notice: notice)
                    .allowsHitTesting(false)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.default, value: notice)
    }
}

// What a notice says: a title, and an optional second line.
//
// Conformances:
// - `Equatable`, so the toast animates in and out when its notice changes.
struct Notice: Equatable {
    let title: String
    let detail: String?
}

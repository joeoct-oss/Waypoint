//
//  DetailReviewViews.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import SwiftUI

// The Write a review flow's first screen: one button for each number of stars, and a tap reports
// the stars picked.
struct DetailReviewRatingView: View {
    private static let ratings = 1...5

    let onRate: (Int) -> Void

    var body: some View {
        List {
            Section {
                ForEach(Self.ratings, id: \.self) { rating in
                    Button(DetailReviewText.stars(rating)) { onRate(rating) }
                        .accessibilityIdentifier(Identifiers.detailReviewStars(rating))
                }
            } footer: {
                Text("A child flow pushed on the Detail push stack. Back from here ends it.")
            }
        }
        .exampleList()
        .accessibilityIdentifier(Identifiers.detailReviewRating)
    }
}

// The Write a review flow's note: the stars picked, and Post review, which finishes the flow.
struct DetailReviewNoteView: View {
    let rating: Int
    let onPost: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.large) {
                LabNote(
                    title: DetailReviewText.stars(rating),
                    detail: "Post review calls finish(with:), which pops back to the product and "
                        + "hands the stars to the Detail push flow."
                )
            }
            .padding(Spacing.large)
        }
        .background(Palette.background.color)
        .accessibilityIdentifier(Identifiers.detailReviewNote)
        .bottomActionBar { postButton }
    }

    private var postButton: some View {
        PrimaryActionButton(
            title: "Post review",
            identifier: Identifiers.detailReviewPost,
            action: onPost
        )
    }
}

// The words the review screens and the product show for a number of stars.
nonisolated enum DetailReviewText {
    static func stars(_ rating: Int) -> String {
        rating == 1 ? "1 star" : "\(rating) stars"
    }
}

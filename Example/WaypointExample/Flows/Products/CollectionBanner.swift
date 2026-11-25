//
//  CollectionBanner.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import ExampleCatalog
import ExampleDesignSystem
import ExampleStore
import SwiftUI

// The banner at the top of Shop for a new collection: a night-sky gradient with the collection's
// name, its tagline and a small constellation. The banner reports a tap.
struct CollectionBanner: View {
    private static let skyColors = [
        Color(artHex: 0x1B1F4A),
        Color(artHex: 0x4F5BD5),
        Color(artHex: 0xD62F86),
    ]

    let collection: ProductCollection
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            content
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(Identifiers.collection(id: collection.id))
    }

    private var content: some View {
        HStack(spacing: Spacing.small) {
            titles
            CollectionConstellation()
                .frame(width: Size.bannerArtWidth, height: Size.bannerArtHeight)
        }
        .padding(Spacing.large)
        .foregroundStyle(.white)
        .background(sky, in: RoundedRectangle(cornerRadius: Radius.banner))
        .accessibilityElement(children: .combine)
    }

    private var titles: some View {
        VStack(alignment: .leading, spacing: Spacing.extraSmall) {
            Text("New collection")
                .font(Typography.label)
                .textCase(.uppercase)
                .opacity(0.8)
            Text(collection.name)
                .font(Typography.display)
            Text(collection.tagline)
                .font(Typography.footnote)
                .opacity(0.85)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var sky: LinearGradient {
        LinearGradient(
            colors: Self.skyColors,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

// The banner's constellation: six stars, four of them joined by a line, and a glow around the
// brightest. Drawn on the canvas artwork's 100 by 60 grid.
private struct CollectionConstellation: View {
    private static let gridWidth: CGFloat = 100
    private static let gridHeight: CGFloat = 60
    private static let stars = [
        Star(x: 18, y: 20, radius: 1.6, opacity: 0.9),
        Star(x: 44, y: 12, radius: 1.2, opacity: 0.7),
        Star(x: 70, y: 26, radius: 2, opacity: 1),
        Star(x: 88, y: 14, radius: 1.2, opacity: 0.6),
        Star(x: 60, y: 44, radius: 1.4, opacity: 0.8),
        Star(x: 30, y: 46, radius: 1, opacity: 0.6),
    ]
    private static let line = [
        CGPoint(x: 18, y: 20),
        CGPoint(x: 44, y: 12),
        CGPoint(x: 70, y: 26),
        CGPoint(x: 60, y: 44),
    ]

    var body: some View {
        Canvas { context, size in
            drawSky(in: context, size: size)
        }
        .accessibilityHidden(true)
    }

    private func drawSky(in context: GraphicsContext, size: CGSize) {
        // `var` because scaling a graphics context changes it in place, here only.
        var grid = context
        grid.scaleBy(x: size.width / Self.gridWidth, y: size.height / Self.gridHeight)
        let glow = Path(ellipseIn: CGRect(x: 63, y: 19, width: 14, height: 14))
        grid.fill(glow, with: .color(Color(artHex: 0xFFC857).opacity(0.25)))
        let joined = Path { path in
            path.addLines(Self.line)
        }
        grid.stroke(joined, with: .color(Color(artHex: 0x9AA2E8)), lineWidth: 0.8)
        for star in Self.stars {
            let bounds = CGRect(
                x: star.x - star.radius,
                y: star.y - star.radius,
                width: star.radius * 2,
                height: star.radius * 2
            )
            grid.fill(Path(ellipseIn: bounds), with: .color(.white.opacity(star.opacity)))
        }
    }
}

// One star of the banner's constellation, on its 100 by 60 grid.
private struct Star {
    let x: CGFloat
    let y: CGFloat
    let radius: CGFloat
    let opacity: Double
}

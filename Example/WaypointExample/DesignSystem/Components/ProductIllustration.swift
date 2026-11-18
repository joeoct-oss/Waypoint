//
//  ProductIllustration.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import SwiftUI

// A product's illustration, drawn from the design canvas's artwork on a 100 by 100 grid and scaled
// to fit a square. It draws its own gradient backdrop unless the screen draws one around it, as the
// product page does. The illustrations are decoration: the product's name is always next to them,
// so VoiceOver skips them.
struct ProductIllustration: View {
    let artwork: ProductArtwork
    let drawsBackdrop: Bool

    var body: some View {
        Canvas { context, size in
            let painter = ArtPainter(context: context, size: size)
            if drawsBackdrop {
                painter.fillBackdrop(artwork.backdrop)
            }
            painter.draw(artwork)
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityHidden(true)
    }
}

// The gradient behind a product's illustration, for screens that draw a larger backdrop than the
// illustration's own square.
struct ProductBackdrop: View {
    let artwork: ProductArtwork

    var body: some View {
        let colors = [
            Color(artHex: artwork.backdrop.start),
            Color(artHex: artwork.backdrop.end),
        ]
        LinearGradient(
            colors: colors,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

// Draws shapes given on the artwork's 100 by 100 grid into a square centered in the canvas.
private struct ArtPainter {
    private static let grid: CGFloat = 100

    // The canvas's context, moved and scaled so the artwork's grid fills the centered square.
    private let context: GraphicsContext

    init(context: GraphicsContext, size: CGSize) {
        let side = min(size.width, size.height)
        let scale = side / Self.grid
        // `var` because moving and scaling a graphics context changes it in place, here only.
        var grid = context
        grid.translateBy(x: (size.width - side) / 2, y: (size.height - side) / 2)
        grid.scaleBy(x: scale, y: scale)
        self.context = grid
    }

    func fillBackdrop(_ colors: (start: UInt32, end: UInt32)) {
        let square = Path(CGRect(x: 0, y: 0, width: Self.grid, height: Self.grid))
        let stops = [
            Color(artHex: colors.start),
            Color(artHex: colors.end),
        ]
        let gradient = Gradient(colors: stops)
        let shading = GraphicsContext.Shading.linearGradient(
            gradient,
            startPoint: .zero,
            endPoint: CGPoint(x: Self.grid, y: Self.grid)
        )
        context.fill(square, with: shading)
    }

    func draw(_ artwork: ProductArtwork) {
        switch artwork {
        case .orbitLamp:
            drawOrbitLamp()
        case .cometMug:
            drawCometMug()
        case .nebulaThrow:
            drawNebulaThrow()
        case .starChartPrint:
            drawStarChartPrint()
        case .poleStarCandle:
            drawPoleStarCandle()
        case .poleStarLamp:
            drawPoleStarLamp()
        }
    }

    private func drawOrbitLamp() {
        fillCircle(x: 50, y: 40, radius: 26, hex: ArtColor.glow, opacity: 0.35)
        strokeOrbit()
        fillCircle(x: 50, y: 40, radius: 11, hex: ArtColor.gold)
        fillCircle(x: 71, y: 33, radius: 4, hex: ArtColor.nova)
        fillRoundedRect(CGRect(x: 47.5, y: 50, width: 5, height: 26), radius: 2.5, hex: ArtColor.ink)
        fillEllipse(x: 50, y: 80, radiusX: 18, radiusY: 5, hex: ArtColor.ink)
    }

    // The lamp's ring: an ellipse around the bulb, tilted 18 degrees.
    private func strokeOrbit() {
        // `var` because rotating a graphics context changes it in place, here only.
        var tilted = context
        tilted.translateBy(x: 50, y: 40)
        tilted.rotate(by: .degrees(-18))
        let ring = Path(ellipseIn: CGRect(x: -24, y: -9, width: 48, height: 18))
        tilted.stroke(ring, with: .color(Color(artHex: ArtColor.starLine)), lineWidth: 4)
    }

    private func drawCometMug() {
        let steam = Path { path in
            path.move(to: CGPoint(x: 38, y: 22))
            path.addCurve(
                to: CGPoint(x: 44, y: 10),
                control1: CGPoint(x: 38, y: 16),
                control2: CGPoint(x: 44, y: 16)
            )
            path.move(to: CGPoint(x: 50, y: 22))
            path.addCurve(
                to: CGPoint(x: 56, y: 10),
                control1: CGPoint(x: 50, y: 16),
                control2: CGPoint(x: 56, y: 16)
            )
        }
        stroke(steam, hex: ArtColor.mist, width: 3, cap: .round)
        let handle = Path { path in
            path.move(to: CGPoint(x: 66, y: 40))
            path.addLine(to: CGPoint(x: 72, y: 40))
            path.addArc(
                center: CGPoint(x: 72, y: 50),
                radius: 10,
                startAngle: .degrees(-90),
                endAngle: .degrees(90),
                clockwise: false
            )
            path.addLine(to: CGPoint(x: 66, y: 60))
        }
        stroke(handle, hex: ArtColor.starLine, width: 6)
        fillRoundedRect(CGRect(x: 26, y: 30, width: 42, height: 48), radius: 8, hex: ArtColor.starLine)
        let tail = Path { path in
            path.move(to: CGPoint(x: 32, y: 62))
            path.addLine(to: CGPoint(x: 52, y: 48))
        }
        stroke(tail, hex: ArtColor.gold, width: 4, cap: .round, opacity: 0.55)
        fillCircle(x: 54, y: 46, radius: 5, hex: ArtColor.gold)
        fillEllipse(x: 47, y: 80, radiusX: 24, radiusY: 4, hex: ArtColor.ink, opacity: 0.18)
    }

    private func drawNebulaThrow() {
        fillRoundedRect(CGRect(x: 18, y: 52, width: 64, height: 20), radius: 8, hex: ArtColor.violet)
        fillRoundedRect(CGRect(x: 18, y: 38, width: 64, height: 20), radius: 8, hex: ArtColor.nova)
        fillRoundedRect(CGRect(x: 18, y: 24, width: 64, height: 20), radius: 8, hex: ArtColor.starLine)
        let wave = Path { path in
            path.move(to: CGPoint(x: 24, y: 34))
            path.addCurve(
                to: CGPoint(x: 46, y: 32),
                control1: CGPoint(x: 32, y: 28),
                control2: CGPoint(x: 38, y: 38)
            )
            path.addCurve(
                to: CGPoint(x: 68, y: 30),
                control1: CGPoint(x: 54, y: 26),
                control2: CGPoint(x: 60, y: 36)
            )
        }
        stroke(wave, hex: ArtColor.white, width: 2.5, opacity: 0.6)
        fillCircle(x: 30, y: 62, radius: 2, hex: ArtColor.white)
        fillCircle(x: 58, y: 65, radius: 1.6, hex: ArtColor.white)
        fillCircle(x: 70, y: 47, radius: 1.8, hex: ArtColor.white)
        fillEllipse(x: 50, y: 80, radiusX: 34, radiusY: 4, hex: ArtColor.ink, opacity: 0.18)
    }

    private func drawStarChartPrint() {
        fillRoundedRect(CGRect(x: 22, y: 14, width: 56, height: 70), radius: 3, hex: ArtColor.frame)
        fillRoundedRect(CGRect(x: 27, y: 19, width: 46, height: 60), radius: 0, hex: ArtColor.ink)
        let lines = Path { path in
            let upper = [
                CGPoint(x: 36, y: 34),
                CGPoint(x: 48, y: 42),
                CGPoint(x: 58, y: 36),
                CGPoint(x: 64, y: 50),
            ]
            path.addLines(upper)
            let lower = [
                CGPoint(x: 48, y: 42),
                CGPoint(x: 44, y: 60),
                CGPoint(x: 58, y: 64),
            ]
            path.addLines(lower)
        }
        stroke(lines, hex: ArtColor.mist, width: 1.4)
        fillCircle(x: 36, y: 34, radius: 2.4, hex: ArtColor.white)
        fillCircle(x: 48, y: 42, radius: 2, hex: ArtColor.white)
        fillCircle(x: 58, y: 36, radius: 2.6, hex: ArtColor.gold)
        fillCircle(x: 64, y: 50, radius: 1.8, hex: ArtColor.white)
        fillCircle(x: 44, y: 60, radius: 2, hex: ArtColor.white)
        fillCircle(x: 58, y: 64, radius: 2.2, hex: ArtColor.nova)
    }

    private func drawPoleStarCandle() {
        fillCircle(x: 50, y: 28, radius: 14, hex: ArtColor.glow, opacity: 0.35)
        let flame = Path { path in
            path.move(to: CGPoint(x: 50, y: 18))
            path.addCurve(
                to: CGPoint(x: 50, y: 32),
                control1: CGPoint(x: 55, y: 24),
                control2: CGPoint(x: 55, y: 30)
            )
            path.addCurve(
                to: CGPoint(x: 50, y: 18),
                control1: CGPoint(x: 45, y: 30),
                control2: CGPoint(x: 45, y: 24)
            )
            path.closeSubpath()
        }
        context.fill(flame, with: .color(Color(artHex: ArtColor.flame)))
        fillRoundedRect(CGRect(x: 49, y: 32, width: 2, height: 6), radius: 0, hex: ArtColor.ink)
        let jar = Path(roundedRect: CGRect(x: 30, y: 38, width: 40, height: 42), cornerRadius: 6)
        context.fill(jar, with: .color(Color(artHex: ArtColor.wax)))
        context.stroke(jar, with: .color(Color(artHex: ArtColor.ink)), lineWidth: 2)
        fillRoundedRect(CGRect(x: 30, y: 52, width: 40, height: 16), radius: 0, hex: ArtColor.starLine)
        let star = Path { path in
            let corners = [
                CGPoint(x: 50, y: 55),
                CGPoint(x: 51.8, y: 58.7),
                CGPoint(x: 55.8, y: 59.3),
                CGPoint(x: 52.9, y: 62.1),
                CGPoint(x: 53.6, y: 66.1),
                CGPoint(x: 50, y: 64.2),
                CGPoint(x: 46.4, y: 66.1),
                CGPoint(x: 47.1, y: 62.1),
                CGPoint(x: 44.2, y: 59.3),
                CGPoint(x: 48.2, y: 58.7),
            ]
            path.addLines(corners)
            path.closeSubpath()
        }
        context.fill(star, with: .color(Color(artHex: ArtColor.gold)))
    }

    private func drawPoleStarLamp() {
        let shade = Path { path in
            path.move(to: CGPoint(x: 30, y: 46))
            path.addArc(
                center: CGPoint(x: 50, y: 46),
                radius: 20,
                startAngle: .degrees(180),
                endAngle: .degrees(360),
                clockwise: false
            )
            path.closeSubpath()
        }
        context.fill(shade, with: .color(Color(artHex: ArtColor.pine)))
        fillCircle(x: 50, y: 48, radius: 6, hex: ArtColor.gold)
        let beams = Path { path in
            path.move(to: CGPoint(x: 40, y: 50))
            path.addLine(to: CGPoint(x: 32, y: 68))
            path.move(to: CGPoint(x: 60, y: 50))
            path.addLine(to: CGPoint(x: 68, y: 68))
        }
        stroke(beams, hex: ArtColor.glow, width: 3, opacity: 0.5)
        fillRoundedRect(CGRect(x: 48, y: 24, width: 4, height: 10), radius: 0, hex: ArtColor.ink)
        fillRoundedRect(CGRect(x: 47.5, y: 52, width: 5, height: 24), radius: 2.5, hex: ArtColor.ink)
        fillEllipse(x: 50, y: 80, radiusX: 16, radiusY: 4.5, hex: ArtColor.ink)
    }

    private func fillCircle(
        x: CGFloat,
        y: CGFloat,
        radius: CGFloat,
        hex: UInt32,
        opacity: Double = 1
    ) {
        fillEllipse(
            x: x,
            y: y,
            radiusX: radius,
            radiusY: radius,
            hex: hex,
            opacity: opacity
        )
    }

    private func fillEllipse(
        x: CGFloat,
        y: CGFloat,
        radiusX: CGFloat,
        radiusY: CGFloat,
        hex: UInt32,
        opacity: Double = 1
    ) {
        let bounds = CGRect(x: x - radiusX, y: y - radiusY, width: radiusX * 2, height: radiusY * 2)
        context.fill(Path(ellipseIn: bounds), with: .color(Color(artHex: hex).opacity(opacity)))
    }

    private func fillRoundedRect(
        _ rect: CGRect,
        radius: CGFloat,
        hex: UInt32
    ) {
        let shape = Path(roundedRect: rect, cornerRadius: radius)
        context.fill(shape, with: .color(Color(artHex: hex)))
    }

    private func stroke(
        _ path: Path,
        hex: UInt32,
        width: CGFloat,
        cap: CGLineCap = .butt,
        opacity: Double = 1
    ) {
        let style = StrokeStyle(lineWidth: width, lineCap: cap)
        context.stroke(path, with: .color(Color(artHex: hex).opacity(opacity)), style: style)
    }
}

// The fixed colors of the product artwork. They come from the Constellation palette, and stay the
// same in dark mode, because they paint objects rather than the interface.
private enum ArtColor {
    static let ink: UInt32 = 0x1B1F4A
    static let starLine: UInt32 = 0x4F5BD5
    static let nova: UInt32 = 0xD62F86
    static let violet: UInt32 = 0x7B4FD5
    static let gold: UInt32 = 0xFFC857
    static let glow: UInt32 = 0xFFD27A
    static let flame: UInt32 = 0xFFB238
    static let mist: UInt32 = 0x9AA2E8
    static let frame: UInt32 = 0xC9A86A
    static let wax: UInt32 = 0xF4EEE4
    static let pine: UInt32 = 0x1B9A77
    static let white: UInt32 = 0xFFFFFF
}

extension Color {
    // A fixed color from a hex value, for artwork that looks the same in light and dark mode.
    init(artHex hex: UInt32) {
        self.init(uiColor: UIColor(hex: hex))
    }
}

#Preview {
    let columns = [
        GridItem(.adaptive(minimum: 96)),
    ]
    LazyVGrid(columns: columns) {
        ForEach(ProductArtwork.allCases, id: \.self) { artwork in
            ProductIllustration(artwork: artwork, drawsBackdrop: true)
                .clipShape(RoundedRectangle(cornerRadius: Radius.field))
        }
    }
    .padding()
}

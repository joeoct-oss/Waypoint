//
//  PresentationStyle.swift
//  Waypoint
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

/// How a flow is presented.
///
/// Conformances:
/// - `NavigationValue`, so it can be compared and hashed, saved and restored, and sent off the main actor.
/// - `NavigationDescribable`, for a short, stable, private-by-default description in logs, events and test failures.
public struct PresentationStyle: NavigationValue, NavigationDescribable {
    /// The kinds of presentation.
    ///
    /// Conformances:
    /// - `NavigationValue`, so styles can be compared, saved with the state and sent off the main
    ///   actor.
    private enum Kind: NavigationValue {
        /// A sheet, with its own options or `nil` for the router's defaults.
        case sheet(SheetOptions?)
        /// A full-screen cover.
        case fullScreenCover
    }

    /// A sheet that uses the router's default sheet options. Large unless changed.
    public static var sheet: PresentationStyle {
        PresentationStyle(kind: .sheet(nil))
    }

    /// A full-screen cover.
    public static var fullScreenCover: PresentationStyle {
        PresentationStyle(kind: .fullScreenCover)
    }

    /// What kind of presentation this is.
    private let kind: Kind

    /// The sheet's own options, or `nil` for a sheet that uses the router's defaults and for a
    /// full-screen cover.
    public var sheetOptions: SheetOptions? {
        guard case .sheet(let options) = kind else {
            return nil
        }
        return options
    }

    /// Whether this is a full-screen cover.
    public var isFullScreenCover: Bool {
        kind == .fullScreenCover
    }

    /// `sheet`, `sheet(detents: [medium, large])` or `fullScreenCover`.
    public var description: String {
        switch kind {
        case .sheet(let options):
            return Self.sheetDescription(options)
        case .fullScreenCover:
            return "fullScreenCover"
        }
    }

    /// Creates a style of one kind.
    private init(kind: Kind) {
        self.kind = kind
    }

    /// A sheet with the given options.
    public static func sheet(_ options: SheetOptions) -> PresentationStyle {
        PresentationStyle(kind: .sheet(options))
    }

    /// A sheet with the given sizes. `selected` is the size it opens at; `nil` means the first.
    public static func sheet(detents: [SheetDetent], selected: SheetDetent? = nil) -> PresentationStyle {
        sheet(SheetOptions(detents: detents, selectedDetent: selected))
    }

    /// `sheet`, or `sheet(detents: [...])` when the sheet has its own options.
    private static func sheetDescription(_ options: SheetOptions?) -> String {
        guard let options else {
            return "sheet"
        }
        let detents = options.detents.map(\.description).joined(separator: ", ")
        return "sheet(detents: [\(detents)])"
    }

    /// The same line. A style holds no private values.
    public func debugDescription(revealingPrivateValues: Bool) -> String {
        description
    }
}

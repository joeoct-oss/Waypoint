//
//  PresentationDefaults.swift
//  Waypoint
//
//  Created by Yousef Mohamed <52625092+JoeOCT91@users.noreply.github.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

/// Default options for presentations from a router and its children.
///
/// The lookup order is: the call's own options, then the nearest router's
/// `presentationDefaults`, then ``SheetOptions/default``.
///
/// ```swift
/// rootRouter.setPresentationDefaults(PresentationDefaults(sheet: SheetOptions(detents: [.medium, .large])))
/// ```
///
/// Conformances:
/// - `Sendable`, so the configuration can be built anywhere and shared with the whole tree.
/// - `Equatable`, so tests can compare defaults.
public struct PresentationDefaults: Sendable, Equatable {
    /// Large sheets that the user can swipe away.
    public static var `default`: PresentationDefaults {
        PresentationDefaults()
    }

    /// Used by `.sheet` when a call doesn't pass its own options.
    public let sheet: SheetOptions

    /// Creates defaults. Every argument has a default.
    public init(sheet: SheetOptions = .default) {
        self.sheet = sheet
    }

    /// The same defaults with other sheet options.
    public func withSheet(_ sheet: SheetOptions) -> PresentationDefaults {
        PresentationDefaults(sheet: sheet)
    }
}

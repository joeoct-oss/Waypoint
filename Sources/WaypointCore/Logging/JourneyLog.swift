//
//  JourneyLog.swift
//  Waypoint
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

/// The journey log: one box per change in the readable format, with the screen on display, how
/// it got there and the whole app as a tree; one `key=value` line per entry in the structured
/// format.
///
/// ```text
/// ┌─ 🧭 PUSH ▸ ProductDetailView ──────────────────────────────┐
/// │ coordinator  ShopCoordinator · same coordinator (sub view) │
/// │ tab          Shop                                          │
/// │ previous     ProductListView · 2.0 s there                 │
/// │ by           app · ProductsCoordinator.swift:114           │
/// │ route        Product (id: 3)                               │
/// ├─ app ──────────────────────────────────────────────────────┤
/// │ MainCoordinator · tabs                                     │
/// │ ├── Home                    └ HomeView                     │
/// │ ├─▶ Shop · ShopCoordinator                                 │
/// │ │     ├ ProductListView                                    │
/// │ │     └ ProductDetailView (id: 3)   ◀ NEW                  │
/// │ └── Profile                 └ Profile                      │
/// └────────────────────────────────────────────────────────────┘
/// ```
///
/// Wording and symbols are not API; tests pin them.
enum JourneyLog {
    /// The labels in the box are padded to this width.
    static let labelWidth = 12

    /// The narrowest a box's inside is, so boxes one after another line up unless one needs
    /// more room.
    static let minimumWidth = 76

    /// One entry as a `key=value` line, for the structured format.
    static func line(_ entry: JourneyEntry) -> String {
        structured(entry)
    }

    /// A duration as people read it: `180 ms`, `5.7 s` or `2 min 5 s`.
    static func text(_ duration: Duration) -> String {
        let milliseconds = max(milliseconds(duration), 0)
        guard milliseconds >= 1000 else {
            return "\(milliseconds) ms"
        }
        let tenths = (milliseconds + 50) / 100
        guard tenths < 600 else {
            let seconds = (milliseconds + 500) / 1000
            return "\(seconds / 60) min \(seconds % 60) s"
        }
        return "\(tenths / 10).\(tenths % 10) s"
    }

    /// A duration in whole milliseconds.
    static func milliseconds(_ duration: Duration) -> Int64 {
        let (seconds, attoseconds) = duration.components
        return seconds * 1000 + attoseconds / 1_000_000_000_000_000
    }

    /// The structured line of one entry, `key=value` pairs for tools.
    private static func structured(_ entry: JourneyEntry) -> String {
        switch entry {
        case .flowStarted(let flow):
            return structuredFlow("flow_started", flow)
        case .flowEnded(let flow, let cancelled):
            return structuredFlow(cancelled ? "flow_cancelled" : "flow_finished", flow)
        case .tabSelected(let tab, let old, let trigger):
            return structuredTab(tab, from: old, trigger: trigger)
        case .screenViewed(let visit, _):
            return structuredVisit(visit)
        case .duplicate(let screen, let interval, let site):
            return structuredDuplicate(screen, interval: interval, site: site)
        }
    }

    /// `tab_selected tab=Cart from=Shop`.
    private static func structuredTab(_ tab: String, from old: String, trigger: String?) -> String {
        let pairs: [(String, String?)] = [
            ("tab", tab),
            ("from", old),
            ("trigger", trigger),
        ]
        return structuredLine("tab_selected", pairs)
    }

    /// `screen_viewed screen="Product 3" previous="Product list" source="Shop" how=push …`.
    private static func structuredVisit(_ visit: ScreenVisit) -> String {
        let pairs: [(String, String?)] = [
            ("screen", quoted(visit.screen.title)),
            ("display", visit.screen.displayName.map(quoted)),
            ("previous", visit.previous.map { quoted($0.title) }),
            ("source", quoted(visit.source.title)),
            ("how", "\(visit.transition)".replacingOccurrences(of: " ", with: "_")),
            ("origin", "\(visit.origin)"),
            ("flow", visit.screen.flow.name),
            ("depth", "\(visit.depth)"),
            ("step", visit.step.map { "\($0.number)/\($0.count)" }),
            ("trigger", visit.trigger),
            ("after_ms", visit.timeOnPrevious.map { "\(milliseconds($0))" }),
            ("at", visit.callSite),
        ]
        return structuredLine("screen_viewed", pairs)
    }

    /// `flow_started flow=checkout screen="Checkout" from="Cart" style=fullScreenCover …`.
    private static func structuredFlow(_ event: String, _ flow: FlowJourney) -> String {
        let pairs: [(String, String?)] = [
            ("flow", flow.flow.name),
            ("screen", quoted(flow.screen.title)),
            ("from", flow.presenter.map { quoted($0.title) }),
            ("style", flow.style.isFullScreenCover ? "fullScreenCover" : "sheet"),
            ("origin", "\(flow.origin)"),
            ("trigger", flow.trigger),
            ("duration_ms", flow.duration.map { "\(milliseconds($0))" }),
            ("at", flow.callSite),
        ]
        return structuredLine(event, pairs)
    }

    /// `duplicate_screen screen="Product 3" interval_ms=180 at=ProductRow.swift:41`.
    private static func structuredDuplicate(_ screen: ScreenReference, interval: Duration, site: String?) -> String {
        let pairs: [(String, String?)] = [
            ("screen", quoted(screen.title)),
            ("interval_ms", "\(milliseconds(interval))"),
            ("at", site),
        ]
        return structuredLine("duplicate_screen", pairs)
    }

    /// `event key=value key=value`, leaving out the pairs with no value.
    private static func structuredLine(_ event: String, _ pairs: [(String, String?)]) -> String {
        let shown = pairs.compactMap { key, value in
            value.map { "\(key)=\($0)" }
        }
        return ([event] + shown).joined(separator: " ")
    }

    /// `"text"`, with quotes inside escaped.
    private static func quoted(_ text: String) -> String {
        "\"\(text.replacingOccurrences(of: "\"", with: "\\\""))\""
    }
}

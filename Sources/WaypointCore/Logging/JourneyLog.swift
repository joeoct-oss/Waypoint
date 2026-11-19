//
//  JourneyLog.swift
//  Waypoint
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

/// The journey lines: one line per screen the user sees, tab switch and flow, in the words
/// analytics uses, and a box with every field of a visit at `.debug`.
///
/// ```text
/// 🧭 screen_viewed  Product list               source Shop
/// 🧭 screen_viewed  Product 3 "Orbit Lamp"     ◀ Product list after 2.1 s · push by app (ProductListView.swift:88)
/// 🧭 tab_selected   Cart                       ◀ Shop
/// 🧭 flow_started   Checkout                   from Cart · full screen · by app (CartCoordinator.swift:150)
/// ⚠️ duplicate      Product 3 viewed twice, 180 ms apart (ProductRow.swift:41)
/// ```
///
/// Wording and symbols are not API (decision 0015); tests pin them.
enum JourneyLog {
    /// Event names are padded to this width.
    static let eventWidth = 14

    /// Subjects are padded to this width before the details.
    static let subjectWidth = 26

    /// The width of the debug box's top and bottom rules.
    static let boxWidth = 44

    /// The labels in the debug box are padded to this width.
    static let boxLabelWidth = 9

    /// One entry as a line in the configured format.
    static func line(_ entry: JourneyEntry, naming: RouteNaming) -> String {
        guard naming.format == .readable else {
            return structured(entry)
        }
        return readable(entry, symbols: naming.usesSymbols)
    }

    /// The debug box of one visit, with every field.
    ///
    /// ```text
    /// ┌─ 🧭 screen_viewed · Product 3 ─────────────
    /// │  screen    : Product 3 "Orbit Lamp"
    /// │  route     : Product (id: 3)
    /// │  previous  : Product list, after 2.1 s
    /// │  source    : Shop
    /// │  how       : push, by app at ProductListView.swift:88
    /// │  journey   : Shop › Product list › Product 3 (depth 2)
    /// │  flow      : shop
    /// └────────────────────────────────────────────
    /// ```
    static func box(_ visit: ScreenVisit, naming: RouteNaming) -> String {
        let symbols = naming.usesSymbols
        let title = "\(mark(symbols)) screen_viewed \(dot(symbols)) \(visit.screen.title) "
        let rule = symbols ? "─" : "-"
        let top = (symbols ? "┌─ " : "+- ") + title
        let topLine = top + String(repeating: rule, count: max(boxWidth - top.count, 3))
        let bottom = (symbols ? "└" : "+") + String(repeating: rule, count: boxWidth)
        let rows = boxRows(visit, naming: naming).map { label, value in
            "\(symbols ? "│" : "|")  \(padded(label, boxLabelWidth)) : \(value)"
        }
        return ([topLine] + rows + [bottom]).joined(separator: "\n")
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

    /// The readable line of one entry.
    private static func readable(_ entry: JourneyEntry, symbols: Bool) -> String {
        switch entry {
        case .flowStarted(let flow):
            return flowStartedLine(flow, symbols: symbols)
        case .flowEnded(let flow, let cancelled):
            return flowEndedLine(flow, cancelled: cancelled, symbols: symbols)
        case .tabSelected(let tab, let old, let trigger):
            return tabLine(tab, from: old, trigger: trigger, symbols: symbols)
        case .screenViewed(let visit, let showsSource):
            return visitLine(visit, showsSource: showsSource, symbols: symbols)
        case .duplicate(let screen, let interval, let site):
            return duplicateLine(screen, interval: interval, site: site, symbols: symbols)
        }
    }

    /// `🧭 screen_viewed  Product 3  ◀ Product list after 2.1 s · push by app (…)`.
    private static func visitLine(_ visit: ScreenVisit, showsSource: Bool, symbols: Bool) -> String {
        let previous = visit.previous.map { screen in
            "\(arrow(symbols)) \(screen.title)" + (visit.timeOnPrevious.map { " after \(text($0))" } ?? "")
        }
        let source = showsSource ? "source \(visit.source.title)" : nil
        let how = visit.transition == .appear ? nil : howText(visit.transition, visit.origin, visit.callSite)
        let step = visit.step.map { "step \($0.number) of \($0.count)" }
        let trigger = visit.trigger.map { "trigger \($0)" }
        let details = [previous, source, how, step, trigger].compactMap { $0 }
        return journeyLine("screen_viewed", visit.screen.description, details, symbols: symbols)
    }

    /// `🧭 tab_selected   Cart  ◀ Shop`.
    private static func tabLine(_ tab: String, from old: String, trigger: String?, symbols: Bool) -> String {
        let details = ["\(arrow(symbols)) \(old)", trigger.map { "trigger \($0)" }].compactMap { $0 }
        return journeyLine("tab_selected", tab, details, symbols: symbols)
    }

    /// `🧭 flow_started   Checkout  from Cart · full screen · by app (…)`.
    private static func flowStartedLine(_ flow: FlowJourney, symbols: Bool) -> String {
        let from = flow.presenter.map { "from \($0.title)" }
        let style = flow.style.isFullScreenCover ? "full screen" : "sheet"
        let by = byText(flow.origin, flow.callSite)
        let trigger = flow.trigger.map { "trigger \($0)" }
        let details = [from, style, by, trigger].compactMap { $0 }
        return journeyLine("flow_started", flow.screen.title, details, symbols: symbols)
    }

    /// `🧭 flow_finished  Checkout  after 42.0 s · by app (…)`, or `flow_cancelled … by user`.
    private static func flowEndedLine(_ flow: FlowJourney, cancelled: Bool, symbols: Bool) -> String {
        let after = flow.duration.map { "after \(text($0))" }
        let details = [after, byText(flow.origin, flow.callSite)].compactMap { $0 }
        return journeyLine(cancelled ? "flow_cancelled" : "flow_finished", flow.screen.title, details, symbols: symbols)
    }

    /// `⚠️ duplicate      Product 3 viewed twice, 180 ms apart (ProductRow.swift:41)`.
    private static func duplicateLine(
        _ screen: ScreenReference,
        interval: Duration,
        site: String?,
        symbols: Bool
    ) -> String {
        let siteText = site.map { " (\($0))" } ?? ""
        let warning = symbols ? "⚠️" : "Waypoint"
        let message = "\(screen.title) viewed twice, \(text(interval)) apart\(siteText)"
        return "\(warning) \(padded("duplicate", eventWidth)) \(message)"
    }

    /// `🧭 event  subject  detail · detail`.
    private static func journeyLine(_ event: String, _ subject: String, _ details: [String], symbols: Bool) -> String {
        let head = "\(mark(symbols)) \(padded(event, eventWidth)) "
        guard !details.isEmpty else {
            return head + subject
        }
        return head + padded(subject, subjectWidth) + " " + details.joined(separator: " \(dot(symbols)) ")
    }

    /// `push by app (ProductListView.swift:88)`, or `back by user`.
    private static func howText(
        _ transition: ScreenVisit.Transition,
        _ origin: ScreenVisit.Origin,
        _ site: String?
    ) -> String {
        "\(transition) \(byText(origin, site))"
    }

    /// `by app (ProductListView.swift:88)`, or `by user`.
    private static func byText(_ origin: ScreenVisit.Origin, _ site: String?) -> String {
        "by \(origin)" + (site.map { " (\($0))" } ?? "")
    }

    /// The labels and values of a visit's debug box.
    private static func boxRows(_ visit: ScreenVisit, naming: RouteNaming) -> [(String, String)] {
        let separator = naming.usesSymbols ? " › " : " > "
        let journey = visit.journey.map(\.title).joined(separator: separator) + " (depth \(visit.depth))"
        let previous = visit.previous.map { screen in
            screen.title + (visit.timeOnPrevious.map { ", after \(text($0))" } ?? "")
        }
        let how = "\(visit.transition), by \(visit.origin)" + (visit.callSite.map { " at \($0)" } ?? "")
        let rows: [(String, String?)] = [
            ("screen", visit.screen.description),
            ("route", visit.screen.route.map(naming.name)),
            ("previous", previous),
            ("source", visit.source.title),
            ("how", how),
            ("journey", journey),
            ("step", visit.step.map { "\($0.number) of \($0.count)" }),
            ("trigger", visit.trigger),
            ("flow", visit.screen.flow.name),
        ]
        return rows.compactMap { label, value in
            value.map { (label, $0) }
        }
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

    /// `🧭`, or `Waypoint` without symbols.
    private static func mark(_ symbols: Bool) -> String {
        symbols ? "🧭" : "Waypoint"
    }

    /// `◀`, or `<-` without symbols.
    private static func arrow(_ symbols: Bool) -> String {
        symbols ? "◀" : "<-"
    }

    /// `·`, or `|` without symbols.
    private static func dot(_ symbols: Bool) -> String {
        symbols ? "·" : "|"
    }

    /// `text` with spaces after it up to `width`, and none past it.
    private static func padded(_ text: String, _ width: Int) -> String {
        text.padding(toLength: max(width, text.count), withPad: " ", startingAt: 0)
    }
}

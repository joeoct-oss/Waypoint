//
//  JourneyBox.swift
//  Waypoint
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

/// The box one change writes in the readable format: a title with the transition and the screen
/// on display, a row per fact, and the whole app as a tree.
@MainActor
struct JourneyBox {
    /// What the journey wrote for the change.
    let entries: [JourneyEntry]

    /// The screen on display after the change, if any.
    let visible: VisibleScreen?

    /// The root of the tree, for the `app` part.
    let root: any TreeNode

    /// How routes are named and whether symbols are drawn.
    let naming: RouteNaming

    /// The box, or `nil` when the change wrote nothing.
    var rendered: String? {
        guard !entries.isEmpty else {
            return nil
        }
        let facts = rows().map { label, value in
            label.padding(toLength: JourneyLog.labelWidth, withPad: " ", startingAt: 0) + " " + value
        }
        return frame(title: title(), facts: facts, tree: treeLines())
    }

    /// Whether the box draws symbols.
    private var symbols: Bool {
        naming.usesSymbols
    }

    /// The visit the change made, if any.
    private var visit: ScreenVisit? {
        entries.lazy.compactMap { entry -> ScreenVisit? in
            guard case .screenViewed(let visit, _) = entry else {
                return nil
            }
            return visit
        }.first
    }

    /// The screen the box is about: the one on display when it is the visit's, which may have
    /// learned its view's name since, else the visit's, else the one on display.
    private var shownScreen: ScreenReference? {
        guard let screen = visit?.screen else {
            return visible?.screen
        }
        guard let shown = visible?.screen, shown.flow == screen.flow, shown.route == screen.route else {
            return screen
        }
        return shown
    }

    /// The flow the change started, if any.
    private var startedFlow: FlowJourney? {
        entries.lazy.compactMap { entry -> FlowJourney? in
            guard case .flowStarted(let flow) = entry else {
                return nil
            }
            return flow
        }.first
    }

    /// The flows the change ended, with whether the user cancelled each.
    private var endedFlows: [(flow: FlowJourney, cancelled: Bool)] {
        entries.compactMap { entry in
            guard case .flowEnded(let flow, let cancelled) = entry else {
                return nil
            }
            return (flow, cancelled)
        }
    }

    /// The tab left by a tab switch, if any.
    private var tabLeft: String? {
        entries.lazy.compactMap { entry -> String? in
            guard case .tabSelected(_, let old, _) = entry else {
                return nil
            }
            return old
        }.first
    }

    /// How soon the screen came back, when it is a duplicate.
    private var duplicateInterval: Duration? {
        entries.lazy.compactMap { entry -> Duration? in
            guard case .duplicate(_, let interval, _) = entry else {
                return nil
            }
            return interval
        }.first
    }

    /// `🧭 PUSH ▸ ProductDetailView`, with `NEW COORDINATOR` (or `NEW FLOW` when the presenting
    /// coordinator runs it) or `COORDINATOR ENDED` (or `FLOW ENDED` when its coordinator lives on).
    private func title() -> String {
        let screen = shownScreen
        let subject = screen.map { $0.screenLabel } ?? "nothing on display"
        let action = visit.map { Self.word(for: $0.transition) } ?? "CHANGE"
        let started = startedFlow.map { flow in
            let presenter = flow.presenter.map(Self.ownerName)
            return Self.ownerName(flow.screen, in: visit) == presenter ? "NEW FLOW" : "NEW COORDINATOR"
        }
        let ended = endedFlows.first.map { ended in
            endedOwner(of: ended.flow) == nil ? "FLOW ENDED" : "COORDINATOR ENDED"
        }
        let head = "\(symbols ? "🧭" : "Waypoint") \(action) \(symbols ? "▸" : ">") \(subject)"
        return ([head] + [started, ended].compactMap { $0 }).joined(separator: " \(dot) ")
    }

    /// `PUSH`, `BACK`, `TAB`, `SHEET`, `FULL SCREEN`, `DISMISS`, `SET` or `SHOWN`.
    private static func word(for transition: ScreenVisit.Transition) -> String {
        switch transition {
        case .appear:
            return "SHOWN"
        case .fullScreen:
            return "FULL SCREEN"
        case .push, .back, .set, .tab, .sheet, .dismiss:
            return "\(transition)".uppercased()
        }
    }

    /// The labels and values of the box, leaving out the ones with no value.
    private func rows() -> [(String, String)] {
        let rows: [(String, String?)] = [
            ("coordinator", coordinatorText()),
            ("tab", tabText()),
            ("source", sourceText()),
            ("previous", previousText()),
            ("by", byText()),
            ("trigger", visit?.trigger ?? startedFlow?.trigger),
            ("step", visit?.step.map { "\($0.number) of \($0.count)" }),
            ("route", shownScreen?.route.map(naming.name)),
            ("ended", endedText()),
            ("warning", duplicateInterval.map { "shown again \(JourneyLog.text($0)) after the last time" }),
        ]
        return rows.compactMap { label, value in
            value.map { (label, $0) }
        }
    }

    /// `ProductsCoordinator · same coordinator (sub view)`, `CheckoutCoordinator · presented by
    /// CartCoordinator` or `CartCoordinator · tab switch`.
    private func coordinatorText() -> String? {
        guard let screen = shownScreen else {
            return nil
        }
        let owner = screen.coordinator ?? "\(VisibleScreen.words(screen.flow.name)) (no coordinator named)"
        if let started = startedFlow {
            let presenter = started.presenter.map(Self.ownerName) ?? "the app"
            guard presenter != screen.coordinator else {
                return "\(owner) \(dot) new flow \(started.flow.name)"
            }
            return "\(owner) \(dot) presented by \(presenter)"
        }
        guard let visit else {
            return owner
        }
        return relation(of: visit).map { "\(owner) \(dot) \($0)" } ?? owner
    }

    /// How the screen relates to the one before it, when it says something.
    private func relation(of visit: ScreenVisit) -> String? {
        switch visit.transition {
        case .push, .back, .set:
            return visit.previous?.flow == visit.screen.flow ? "same coordinator (sub view)" : nil
        case .tab:
            return "tab switch"
        case .appear, .sheet, .fullScreen, .dismiss:
            return nil
        }
    }

    /// A screen's coordinator, else its flow in words.
    private static func ownerName(_ screen: ScreenReference) -> String {
        screen.coordinator ?? VisibleScreen.words(screen.flow.name)
    }

    /// The owner of a flow's first screen: the visit's screen when it is that flow's, which
    /// knows its coordinator, else the flow's own.
    private static func ownerName(_ screen: ScreenReference, in visit: ScreenVisit?) -> String {
        guard let shown = visit?.screen, shown.flow == screen.flow else {
            return ownerName(screen)
        }
        return ownerName(shown)
    }

    /// The tab the screen on display is in, or under, if any.
    private var tabName: String? {
        visible?.levels.lazy.compactMap { level -> String? in
            guard case .tab(let name) = level.role else {
                return nil
            }
            return name
        }.first
    }

    /// `Cart`, or `Cart (from Shop)` after a tab switch.
    private func tabText() -> String? {
        guard let tab = tabName else {
            return nil
        }
        return tabLeft.map { "\(tab) (from \($0))" } ?? tab
    }

    /// Where this part of the journey started, when a screen in the stack started it: not the
    /// tab, the stack's root screen or the screen itself, which the tree already shows.
    private func sourceText() -> String? {
        let stackRoot = visible?.levels.last?.screens.first?.title
        guard let source = visit?.source.title, source != tabName, source != stackRoot else {
            return nil
        }
        return source == visit?.screen.title ? nil : source
    }

    /// `ProductListView · 2.0 s there`.
    private func previousText() -> String? {
        guard let visit, let previous = visit.previous else {
            return nil
        }
        let label = JourneyTree.label(of: previous, naming: naming)
        return label + (visit.timeOnPrevious.map { " \(dot) \(JourneyLog.text($0)) there" } ?? "")
    }

    /// `app · ProductsCoordinator.swift:114`, or `user`.
    private func byText() -> String? {
        guard let visit, visit.transition != .appear else {
            return nil
        }
        return "\(visit.origin)" + (visit.callSite.map { " \(dot) \($0)" } ?? "")
    }

    /// `checkout · finished after 20.7 s`, or `cancelled by the user after 3.0 s`.
    private func endedText() -> String? {
        let texts = endedFlows.map { ended in
            let name = endedOwner(of: ended.flow) ?? "\(ended.flow.flow.name) flow"
            let how = ended.cancelled ? "cancelled by the user" : "finished"
            let after = ended.flow.duration.map { " after \(JourneyLog.text($0))" } ?? ""
            return "\(name) \(dot) \(how)\(after)"
        }
        return texts.isEmpty ? nil : texts.joined(separator: "; ")
    }

    /// The coordinator of an ended flow, from its last screen, or `nil` when it had none of its
    /// own: unnamed, or the coordinator still on display, which ran the flow and lives on.
    private func endedOwner(of flow: FlowJourney) -> String? {
        let last = visit?.previous.flatMap { $0.flow == flow.flow ? $0 : nil }
        guard let owner = last?.coordinator ?? flow.screen.coordinator, owner != shownScreen?.coordinator else {
            return nil
        }
        return owner
    }

    /// The tree's lines, the screen on display marked `◀ NEW` when it came forward, else
    /// `◀ HERE`.
    private func treeLines() -> [String] {
        let rows = JourneyTree(current: visible?.key, naming: naming).rows(from: root)
        let forward = visit.map { Self.isForward($0.transition) } ?? false
        let marker = (symbols ? "◀ " : "<- ") + (forward ? "NEW" : "HERE")
        return rows.map { row in
            guard row.isCurrent else {
                return row.text
            }
            return row.text + "   " + marker
        }
    }

    /// Whether a transition brought the screen forward.
    private static func isForward(_ transition: ScreenVisit.Transition) -> Bool {
        switch transition {
        case .push, .set, .tab, .sheet, .fullScreen:
            return true
        case .appear, .back, .dismiss:
            return false
        }
    }

    /// The box around the title, the facts and the tree, closed on the right.
    private func frame(title: String, facts: [String], tree: [String]) -> String {
        let section = "app"
        let titleWidth = title.count + (symbols ? 1 : 0)
        let widest = (facts + tree).map(\.count).max() ?? 0
        let contentWidth = max(widest, titleWidth + 4, JourneyLog.minimumWidth)
        let line = symbols ? "─" : "-"
        let side = symbols ? "│" : "|"
        let top = (symbols ? "┌─ " : "+- ") + title + " " + rule(line, contentWidth - titleWidth - 1)
        let middle = (symbols ? "├─ " : "+- ") + section + " " + rule(line, contentWidth - section.count - 1)
        let bottom = (symbols ? "└" : "+") + rule(line, contentWidth + 2)
        let body = { (text: String) in
            "\(side) \(text.padding(toLength: contentWidth, withPad: " ", startingAt: 0)) \(side)"
        }
        let closeTop = symbols ? "┐" : "+"
        let closeMiddle = symbols ? "┤" : "+"
        let closeBottom = symbols ? "┘" : "+"
        let lines = [top + closeTop] + facts.map(body) + [middle + closeMiddle] + tree.map(body)
        return (lines + [bottom + closeBottom]).joined(separator: "\n")
    }

    /// `count` copies of `piece`, at least one.
    private func rule(_ piece: String, _ count: Int) -> String {
        String(repeating: piece, count: max(count, 1))
    }

    /// `·`, or `|` without symbols.
    private var dot: String {
        symbols ? "·" : "|"
    }
}

// Throwaway spike code for the second-assessment spikes A, D, E and F. Rough on purpose; never merged.
// The router is the renderer spike's (#72) small stand-in, plus an alert and a launch-argument switchboard.

import Foundation
import Observation

protocol Route: Hashable, Sendable {
    var title: String { get }
}

/// A screen whose destination is a SwiftUI view.
struct LetterRoute: Route {
    let letter: String
    var title: String { letter }
}

/// A screen whose destination is a SwiftUI view, with a toolbar button.
struct ProductRoute: Route {
    let id: Int
    var title: String { "P\(id)" }
}

/// A screen whose destination is an existing `UIViewController` (a "legacy" screen).
struct LegacyRoute: Route {
    let id: Int
    var title: String { "L\(id)" }
}

struct AnyRoute: Hashable, Sendable {
    let base: any Route
    init(_ base: any Route) { self.base = base }
    var title: String { base.title }
    static func == (lhs: AnyRoute, rhs: AnyRoute) -> Bool { AnyHashable(lhs.base) == AnyHashable(rhs.base) }
    func hash(into hasher: inout Hasher) { hasher.combine(AnyHashable(base)) }
}

enum Host: String, Sendable { case swiftUI, uiKit }

struct Presentation: Identifiable {
    let id = UUID()
    let host: Host
    let router: StackRouter
}

/// Spike F: an alert as a value in the state, with typed buttons.
struct SpikeAlert: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let buttons: [String]
}

@MainActor
@Observable
final class StackRouter {
    let name: String
    let rootTitle: String
    var path: [AnyRoute] = []
    var presented: Presentation?
    var alert: SpikeAlert?

    init(name: String, rootTitle: String) {
        self.name = name
        self.rootTitle = rootTitle
    }

    func push(_ route: any Route) { path.append(AnyRoute(route)) }
    func pushMany(_ routes: [any Route]) { path.append(contentsOf: routes.map(AnyRoute.init)) }

    func pop() {
        guard !path.isEmpty else { return }
        path.removeLast()
    }

    func popToRoot() { path.removeAll() }

    func present(_ host: Host) {
        presented = Presentation(host: host, router: StackRouter(name: "\(name).sheet", rootTitle: "S"))
        SpikeLog.shared.note("present \(name) \(host.rawValue)")
    }

    func dismiss() { presented = nil }

    /// Renderers call this when the user changed the stack (swipe back, back button, long-press menu).
    func rendererDidShow(count: Int, source: String) {
        guard count < path.count else { return }
        path.removeLast(path.count - count)
        SpikeLog.shared.note("userPop \(name)->\(count) \(source)")
    }

    /// Renderers call this when the user dismissed the presented flow interactively.
    func rendererDidDismiss(source: String) {
        guard presented != nil else { return }
        presented = nil
        SpikeLog.shared.note("userDismiss \(name) \(source)")
    }

    /// Renderers call this when an alert button was tapped: the typed result goes to the log.
    func rendererDidAnswerAlert(_ button: String, source: String) {
        guard let shown = alert else { return }
        alert = nil
        SpikeLog.shared.note("alertResult \(shown.title)=\(button) \(source)")
    }

    var deepest: StackRouter { presented?.router.deepest ?? self }

    var summary: String {
        let titles = ([rootTitle] + path.map(\.title)).joined(separator: ",")
        let sheet = presented.map { " [\($0.host.rawValue):\($0.router.summary)]" } ?? ""
        let alertText = alert.map { " alert=\($0.title)" } ?? ""
        return "\(name)=\(titles)\(alertText)\(sheet)"
    }
}

/// One log for the whole app (A, E and F run one window).
@MainActor
@Observable
final class SpikeLog {
    static let shared = SpikeLog()
    var appears: [String] = []
    var notes: [String] = []

    func didAppear(_ title: String) { appears.append(title) }

    func note(_ text: String) {
        notes.append(text)
        print("SPIKE \(text)")
    }

    func clear() {
        appears = []
        notes = []
    }
}

/// Launch arguments: `-scenario a`, `-renderer uiKit`, `-host uikitChild`, `-policy wait`, `-sequenced`, `-rawBridge`.
enum Launch {
    static let arguments = ProcessInfo.processInfo.arguments

    static func value(_ name: String) -> String? {
        guard let index = arguments.firstIndex(of: "-\(name)"), index + 1 < arguments.count else { return nil }
        return arguments[index + 1]
    }

    static func flag(_ name: String) -> Bool { arguments.contains("-\(name)") }

    static var scenario: String { value("scenario") ?? "a" }
    static var renderer: Host { value("renderer") == "uiKit" ? .uiKit : .swiftUI }
}

/// The root router of the single-window scenarios (A, E, F).
@MainActor
enum Roots {
    static let main = StackRouter(name: "main", rootTitle: "Root")

    static var summary: String { main.summary }
}

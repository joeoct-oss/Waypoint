// Throwaway spike code for #72. Rough on purpose; never merged.

import Foundation
import Observation

protocol Route: Hashable, Sendable {
    var title: String { get }
}

struct LetterRoute: Route {
    let letter: String
    var title: String { letter }
}

struct ProductRoute: Route {
    let id: Int
    var title: String { "P\(id)" }
}

/// Erased route: what routers store (decision 0003, point 7).
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

@MainActor
@Observable
final class StackRouter {
    let name: String
    let rootTitle: String
    var path: [AnyRoute] = []
    var presented: Presentation?

    init(name: String, rootTitle: String) {
        self.name = name
        self.rootTitle = rootTitle
    }

    func push(_ route: any Route) { path.append(AnyRoute(route)) }

    /// Several screens in one state change: the renderer should show one push animation.
    func pushMany(_ routes: [any Route]) { path.append(contentsOf: routes.map(AnyRoute.init)) }

    func pop() {
        guard !path.isEmpty else { return }
        path.removeLast()
    }

    func popTo(_ route: any Route) {
        guard let index = path.lastIndex(of: AnyRoute(route)) else { return }
        path.removeSubrange((index + 1)...)
    }

    func popToRoot() { path.removeAll() }

    func present(_ host: Host) {
        presented = Presentation(host: host, router: StackRouter(name: "\(name).sheet", rootTitle: "S"))
    }

    /// Renderers call this when the user changed the stack (swipe back, back button, long-press menu).
    func rendererDidShow(count: Int, source: String) {
        guard count < path.count else { return }
        path.removeLast(path.count - count)
        AppRouter.shared.note("userPop \(name)->\(count) \(source)")
    }

    /// Renderers call this when the user dismissed the presented flow interactively.
    func rendererDidDismiss(source: String) {
        guard presented != nil else { return }
        presented = nil
        AppRouter.shared.note("userDismiss \(name) \(source)")
    }

    var lastLetter: Character {
        path.last(where: { $0.base is LetterRoute }).flatMap { ($0.base as? LetterRoute)?.letter.first } ?? "A"
    }

    var summary: String {
        let titles = ([rootTitle] + path.map(\.title)).joined(separator: ",")
        let sheet = presented.map { " [\($0.host.rawValue):\($0.router.summary)]" } ?? ""
        return "\(name)=\(titles)\(sheet)"
    }
}

enum Tab: String, CaseIterable, Sendable { case a, b, c }

@MainActor
@Observable
final class AppRouter {
    static let shared = AppRouter()

    var selection: Tab = .a
    let tabs: [Tab: StackRouter] = [
        .a: StackRouter(name: "a", rootTitle: "A"),
        .b: StackRouter(name: "b", rootTitle: "A"),
        .c: StackRouter(name: "c", rootTitle: "A"),
    ]
    var appears: [String] = []
    var notes: [String] = []

    func router(_ tab: Tab) -> StackRouter { tabs[tab]! }

    var summary: String {
        "tab=\(selection.rawValue) " + Tab.allCases.map { router($0).summary }.joined(separator: " ")
    }

    func didAppear(_ title: String) { appears.append(title) }
    func note(_ text: String) { notes.append(text) }
    func clearLog() {
        appears = []
        notes = []
    }

    /// One cross-cutting deep link: select a tab, dismiss every sheet and set a path, in one synchronous change.
    /// Format: spike://open?tab=b&path=B,C,D
    func open(_ url: URL) {
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        let tab = items.first { $0.name == "tab" }.flatMap { Tab(rawValue: $0.value ?? "") } ?? .a
        let letters = (items.first { $0.name == "path" }?.value ?? "").split(separator: ",").map(String.init)
        selection = tab
        for router in tabs.values { router.presented = nil }
        router(tab).path = letters.map { AnyRoute(LetterRoute(letter: $0)) }
        note("deepLink \(url.query ?? "")")
    }
}

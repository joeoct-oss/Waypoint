//
//  Model.swift
//  RendererSpike (#250, throwaway)
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import Observation
import SwiftUI

enum ScreenKind: String, Hashable {
    case plain, toolbar, search
}

struct Route: Hashable, Identifiable {
    let number: Int
    let kind: ScreenKind
    let id = UUID()
}

/// The one path model both renderers read. Every scenario is a call on it,
/// as a router would make it.
@Observable
@MainActor
final class PathModel {
    var path: [Route] = []
    var sheetDepth = 0
    private var counter = 0

    var debugText: String {
        "path:" + path.map { String($0.number) }.joined(separator: ",")
    }

    private func next(_ kind: ScreenKind = .plain) -> Route {
        counter += 1
        return Route(number: counter, kind: kind)
    }

    func push(_ kind: ScreenKind = .plain) { path.append(next(kind)) }
    func pushMany(_ count: Int) { path += (0..<count).map { _ in next() } }
    func pop() { if !path.isEmpty { path.removeLast() } }
    func popToRoot() { path = [] }
    func replace(with count: Int) { path = (0..<count).map { _ in next() } }

    /// S3: a push, then a pop to root 150 ms later, while the push animates.
    func pushThenPopMidTransition() {
        push()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { self.popToRoot() }
    }

    /// S9: 20 pushes and pops in quick succession (14 pushes, 6 pops).
    func stress() {
        Task { @MainActor in
            for index in 0..<20 {
                if index % 3 == 2 { pop() } else { push() }
                try? await Task.sleep(nanoseconds: 30_000_000)
            }
        }
    }
}

@Observable
final class Theme {
    var name = "red"
}

private struct SpikeValueKey: EnvironmentKey {
    static let defaultValue = "unset"
}

private struct RouterStandInKey: EnvironmentKey {
    static let defaultValue = "no-router"
}

extension EnvironmentValues {
    var spikeValue: String {
        get { self[SpikeValueKey.self] }
        set { self[SpikeValueKey.self] = newValue }
    }

    var routerStandIn: String {
        get { self[RouterStandInKey.self] }
        set { self[RouterStandInKey.self] = newValue }
    }
}

/// Launch configuration: `-renderer swiftUI|uiKit -scenario <name>`.
struct LaunchConfig {
    enum Renderer: String { case swiftUI, uiKit }
    enum EnvironmentMode: String { case none, keys, whole }

    let renderer: Renderer
    let scenario: String
    let hold: Bool

    var hidesTabBar: Bool { scenario == "C5" }
    var environmentMode: EnvironmentMode {
        if let raw = UserDefaults.standard.string(forKey: "envMode"),
           let mode = EnvironmentMode(rawValue: raw) {
            return mode
        }
        return scenario == "E4" ? .whole : .keys
    }

    static let current: LaunchConfig = {
        let defaults = UserDefaults.standard
        return LaunchConfig(
            renderer: Renderer(rawValue: defaults.string(forKey: "renderer") ?? "") ?? .swiftUI,
            scenario: defaults.string(forKey: "scenario") ?? "S1",
            hold: defaults.string(forKey: "hold") != "0"
        )
    }()
}

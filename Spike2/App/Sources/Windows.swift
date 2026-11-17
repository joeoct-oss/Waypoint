import SwiftUI

// Spike D: one app coordinator per window.

/// Stands in for an app coordinator: one root router, a window number, and the window's link inbox.
@MainActor
@Observable
final class WindowCoordinator {
    private static var count = 0
    let number: Int
    let router: StackRouter
    var links: [String] = []

    init(services: AppServices) {
        Self.count += 1
        number = Self.count
        router = StackRouter(name: "w\(number)", rootTitle: "Window \(number)")
        services.coordinatorsMade += 1
        print("SPIKE coordinator made for window \(number)")
    }

    func open(_ url: URL) {
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        let letters = (items.first { $0.name == "path" }?.value ?? "").split(separator: ",").map(String.init)
        router.path = letters.map { AnyRoute(LetterRoute(letter: $0)) }
        links.append(url.absoluteString)
        print("SPIKE window \(number) got link \(url.absoluteString)")
    }
}

/// App-wide services: one per app, shared by every window.
@MainActor
@Observable
final class AppServices {
    var coordinatorsMade = 0
}

/// The prototype of `WaypointRoot { AppCoordinator() }`: makes the coordinator once per window
/// and keeps it in the window's `@State`.
///
/// `@State` evaluates its initial value every time the view value is made, so a coordinator whose
/// `init` has side effects is built again and again (`-eagerState` shows it). `@StateObject`'s
/// autoclosure runs once per window, so the default keeps the coordinator in a box made that way.
struct WaypointRoot<Content: View>: View {
    final class Box: ObservableObject {
        let coordinator: WindowCoordinator
        init(_ coordinator: WindowCoordinator) { self.coordinator = coordinator }
    }

    @StateObject private var box: Box
    let content: (WindowCoordinator) -> Content

    init(_ make: @autoclosure @escaping () -> WindowCoordinator, @ViewBuilder content: @escaping (WindowCoordinator) -> Content) {
        _box = StateObject(wrappedValue: Box(make()))
        self.content = content
    }

    var body: some View {
        content(box.coordinator)
    }
}

/// The first prototype: the coordinator in `@State`.
struct EagerWaypointRoot<Content: View>: View {
    @State private var coordinator: WindowCoordinator
    let content: (WindowCoordinator) -> Content

    init(_ make: @autoclosure @escaping () -> WindowCoordinator, @ViewBuilder content: @escaping (WindowCoordinator) -> Content) {
        _coordinator = State(wrappedValue: make())
        self.content = content
    }

    var body: some View {
        content(coordinator)
    }
}

struct WindowScreen: View {
    let coordinator: WindowCoordinator
    let services: AppServices
    @Environment(\.openWindow) private var openWindow
    @SceneStorage("path") private var savedPath = ""

    var body: some View {
        NavigationStack(path: pathBinding) {
            screen(coordinator.router.rootTitle)
                .navigationDestination(for: LetterRoute.self) { screen($0.title) }
        }
        // Links: a window that matches the link's `window` value is preferred; any window may take others.
        .handlesExternalEvents(preferring: ["window=\(coordinator.number)"], allowing: ["*"])
        .onOpenURL { coordinator.open($0) }
        .onChange(of: coordinator.router.path) { _, path in
            savedPath = path.map(\.title).joined(separator: ",")
        }
        .onAppear {
            if !savedPath.isEmpty, coordinator.router.path.isEmpty {
                coordinator.router.path = savedPath.split(separator: ",").map { AnyRoute(LetterRoute(letter: String($0))) }
                print("SPIKE window \(coordinator.number) restored \(savedPath)")
            }
        }
    }

    private var pathBinding: Binding<NavigationPath> {
        Binding(
            get: {
                var path = NavigationPath()
                for route in coordinator.router.path { path.append(route.base) }
                return path
            },
            set: { newValue in coordinator.router.rendererDidShow(count: newValue.count, source: "swiftui") }
        )
    }

    private func screen(_ title: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("window=\(coordinator.number) path=\(coordinator.router.path.map(\.title).joined(separator: ",")) links=\(coordinator.links.count) coordinators=\(services.coordinatorsMade)")
                .font(.caption.monospaced())
                .accessibilityIdentifier("windowState")
            Button("push") { coordinator.router.push(LetterRoute(letter: "B\(coordinator.router.path.count)")) }
                .accessibilityIdentifier("push")
            Button("newWindow") { openWindow(id: "main") }
                .accessibilityIdentifier("newWindow")
        }
        .buttonStyle(.bordered)
        .padding()
        .navigationTitle(title)
    }
}

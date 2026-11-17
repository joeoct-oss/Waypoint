import SwiftUI

/// `-anyRoutePath` binds NavigationStack to [AnyRoute] with one erased destination;
/// the default mirrors the router into a NavigationPath with one navigationDestination per route type.
let usesAnyRoutePath = ProcessInfo.processInfo.arguments.contains("-anyRoutePath")

/// -noHold turns off the transition hold below, to show the iOS 17 problem.
let usesTransitionHold = !ProcessInfo.processInfo.arguments.contains("-noHold")

struct StackView: View {
    @Bindable var router: StackRouter

    /// The path on screen. It follows `router.path`, but a change that lands while a
    /// transition runs is held until the transition ends: iOS 17 drops it otherwise.
    @State private var shown: [AnyRoute]?
    @State private var lastApplied = Date.distantPast
    @State private var pending = false

    /// How long a push or pop transition runs.
    private static let transition: TimeInterval = 0.6

    var body: some View {
        Group {
            if usesAnyRoutePath {
                NavigationStack(path: $router.path) {
                    SpikeScreen(router: router, title: router.rootTitle)
                        .navigationDestination(for: AnyRoute.self) { route in
                            SpikeScreen(router: router, title: route.title)
                        }
                }
            } else {
                NavigationStack(path: navigationPath) {
                    SpikeScreen(router: router, title: router.rootTitle)
                        .navigationDestination(for: LetterRoute.self) { SpikeScreen(router: router, title: $0.title) }
                        .navigationDestination(for: ProductRoute.self) { SpikeScreen(router: router, title: $0.title) }
                }
            }
        }
        .onChange(of: router.path) { _, _ in
            scheduleApply()
        }
        .sheet(item: sheetBinding) { presentation in
            switch presentation.host {
            case .swiftUI:
                StackView(router: presentation.router)
            case .uiKit:
                UIKitStack(router: presentation.router).ignoresSafeArea()
            }
        }
    }

    private var displayed: [AnyRoute] {
        usesTransitionHold ? (shown ?? router.path) : router.path
    }

    /// Applies the router's path now, or when the running transition ends.
    private func scheduleApply() {
        guard usesTransitionHold else { return }
        let wait = Self.transition - Date().timeIntervalSince(lastApplied)
        if wait <= 0 {
            shown = router.path
            lastApplied = Date()
        } else if !pending {
            pending = true
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(wait))
                pending = false
                // The newest state, never a replay.
                shown = router.path
                lastApplied = Date()
            }
        }
    }

    /// Router path mirrored into a NavigationPath. User pops come back as a shorter count.
    private var navigationPath: Binding<NavigationPath> {
        Binding(
            get: {
                var path = NavigationPath()
                for route in displayed { path.append(route.base) }
                return path
            },
            set: { newValue in
                if newValue.count < displayed.count {
                    if usesTransitionHold {
                        shown = Array(displayed.prefix(newValue.count))
                    }
                    router.rendererDidShow(count: newValue.count, source: "swiftui")
                } else if newValue.count > displayed.count {
                    AppRouter.shared.note("unsupported user push (NavigationLink(value:))")
                }
            }
        )
    }

    private var sheetBinding: Binding<Presentation?> {
        Binding(
            get: { router.presented },
            set: { newValue in if newValue == nil { router.rendererDidDismiss(source: "swiftui") } }
        )
    }
}

struct SpikeScreen: View {
    let router: StackRouter
    let title: String

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                DebugState()
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())]) {
                    ForEach(SpikeAction.all) { action in
                        Button(action.id) { action.run(router) }
                            .buttonStyle(.bordered)
                            .accessibilityIdentifier(action.id)
                    }
                }
            }
            .padding()
        }
        .navigationTitle(title)
        .onAppear { AppRouter.shared.didAppear(title) }
    }
}

struct DebugState: View {
    var body: some View {
        let app = AppRouter.shared
        VStack(alignment: .leading) {
            Text(app.summary).accessibilityIdentifier("state")
            Text("appears: " + app.appears.joined(separator: ",")).accessibilityIdentifier("appears")
            Text("notes: " + app.notes.joined(separator: " | ")).accessibilityIdentifier("notes")
        }
        .font(.caption2.monospaced())
    }
}

struct UIKitStack: UIViewControllerRepresentable {
    let router: StackRouter
    func makeUIViewController(context: Context) -> StackNavigationController { StackNavigationController(router: router) }
    func updateUIViewController(_ controller: StackNavigationController, context: Context) {}
}

struct RootView: View {
    @Bindable var app = AppRouter.shared

    var body: some View {
        TabView(selection: $app.selection) {
            StackView(router: app.router(.a)).tabItem { Label("SwiftUI A", systemImage: "a.circle") }.tag(Tab.a)
            StackView(router: app.router(.b)).tabItem { Label("SwiftUI B", systemImage: "b.circle") }.tag(Tab.b)
            UIKitStack(router: app.router(.c)).ignoresSafeArea().tabItem { Label("UIKit C", systemImage: "c.circle") }.tag(Tab.c)
        }
    }
}

@main
struct SpikeApp: App {
    var body: some Scene {
        WindowGroup {
            RootView().onOpenURL { AppRouter.shared.open($0) }
        }
    }
}

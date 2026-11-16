import SwiftUI

/// `-anyRoutePath` binds NavigationStack to [AnyRoute] with one erased destination;
/// the default mirrors the router into a NavigationPath with one navigationDestination per route type.
let usesAnyRoutePath = ProcessInfo.processInfo.arguments.contains("-anyRoutePath")

struct StackView: View {
    @Bindable var router: StackRouter

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
        .sheet(item: sheetBinding) { presentation in
            switch presentation.host {
            case .swiftUI: StackView(router: presentation.router)
            case .uiKit: UIKitStack(router: presentation.router).ignoresSafeArea()
            }
        }
    }

    /// Router path mirrored into a NavigationPath. User pops come back as a shorter count.
    private var navigationPath: Binding<NavigationPath> {
        Binding(
            get: {
                var path = NavigationPath()
                for route in router.path { path.append(route.base) }
                return path
            },
            set: { newValue in
                if newValue.count < router.path.count {
                    router.rendererDidShow(count: newValue.count, source: "swiftui")
                } else if newValue.count > router.path.count {
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

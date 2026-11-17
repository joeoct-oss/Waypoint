import SwiftUI
import UIKit

/// The renderer spike's SwiftUI stack, with three additions:
/// - A: destinations can be SwiftUI views or UIKit controllers (`LegacyRoute`), bridged.
/// - E: the sheet waits for (or dismisses) a presentation Waypoint didn't make.
/// - F: the router's alert is shown in order with sheet dismissals (`-sequenced`).
struct StackView: View {
    @Bindable var router: StackRouter

    @State private var shown: [AnyRoute]?
    @State private var lastApplied = Date.distantPast
    @State private var pending = false
    /// F: true from the moment the sheet binding goes nil until SwiftUI's `onDismiss` runs.
    @State private var sheetClosing = false
    @State private var foreign = ForeignWatch.shared

    private static let transition: TimeInterval = 0.6

    var body: some View {
        NavigationStack(path: navigationPath) {
            SpikeScreen(router: router, title: router.rootTitle)
                .navigationDestination(for: LetterRoute.self) { SpikeScreen(router: router, title: $0.title) }
                .navigationDestination(for: ProductRoute.self) { ProductScreen(router: router, route: $0) }
                .navigationDestination(for: LegacyRoute.self) { route in
                    ControllerScreen(title: route.title) { LegacyViewController(router: router, route: route) }
                }
        }
        .onChange(of: router.path) { _, _ in scheduleApply() }
        .onChange(of: router.presented?.id) { _, newValue in
            if newValue == nil, !sheetClosing { sheetClosing = true }
            if newValue != nil { foreign.routerWantsToPresent() }
        }
        .sheet(item: sheetBinding, onDismiss: {
            sheetClosing = false
            SpikeLog.shared.note("swiftui onDismiss \(router.name)")
        }) { presentation in
            Group {
                switch presentation.host {
                case .swiftUI:
                    StackView(router: presentation.router)
                case .uiKit:
                    UIKitStack(router: presentation.router).ignoresSafeArea()
                }
            }
            .background(OwnedPresentationMarker())
            .onAppear { foreign.waypointDidPresent(source: "swiftui") }
        }
        .alert(
            router.alert?.title ?? "",
            isPresented: alertBinding,
            presenting: router.alert
        ) { alert in
            ForEach(alert.buttons, id: \.self) { button in
                Button(button) { router.rendererDidAnswerAlert(button, source: "swiftui") }
                    .accessibilityIdentifier("alert.\(button)")
            }
        }
    }

    // MARK: F, alerts

    /// Naive: show the router's alert whenever it is set. Sequenced: only when this flow is on top
    /// (no sheet over it, none closing), so the alert never races a dismissal or lands under a sheet.
    private var alertBinding: Binding<Bool> {
        Binding(
            get: {
                guard router.alert != nil else { return false }
                guard Launch.flag("sequenced") else { return true }
                return router.presented == nil && !sheetClosing
            },
            set: { newValue in
                if !newValue, router.alert != nil {
                    // SwiftUI closes the alert after a button action; the action already reported it.
                    SpikeLog.shared.note("swiftui alert binding set false \(router.name)")
                }
            }
        )
    }

    // MARK: E, foreign presentations

    private var sheetBinding: Binding<Presentation?> {
        Binding(
            get: {
                guard let presented = router.presented else { return nil }
                return foreign.allowsPresenting ? presented : nil
            },
            set: { newValue in
                if newValue == nil, router.presented != nil, foreign.allowsPresenting {
                    router.rendererDidDismiss(source: "swiftui")
                }
            }
        )
    }

    // MARK: Stack, from the renderer spike

    private var displayed: [AnyRoute] { shown ?? router.path }

    private func scheduleApply() {
        let wait = Self.transition - Date().timeIntervalSince(lastApplied)
        if wait <= 0 {
            shown = router.path
            lastApplied = Date()
        } else if !pending {
            pending = true
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(wait))
                pending = false
                shown = router.path
                lastApplied = Date()
            }
        }
    }

    private var navigationPath: Binding<NavigationPath> {
        Binding(
            get: {
                var path = NavigationPath()
                for route in displayed { path.append(route.base) }
                return path
            },
            set: { newValue in
                if newValue.count < displayed.count {
                    shown = Array(displayed.prefix(newValue.count))
                    router.rendererDidShow(count: newValue.count, source: "swiftui")
                }
            }
        )
    }
}

/// A plain spike screen: state, logs and the action buttons.
struct SpikeScreen: View {
    let router: StackRouter
    let title: String

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                DebugState()
                ActionGrid(router: router)
            }
            .padding()
        }
        .navigationTitle(title)
        .onAppear { SpikeLog.shared.didAppear(title) }
        .toolbar {
            if title == router.rootTitle, router.name == "main", let exitTitle = ContainerExit.shared.title {
                ToolbarItem(placement: .topBarLeading) {
                    Button(exitTitle) { ContainerExit.shared.exit() }.accessibilityIdentifier("container.exit")
                }
            }
        }
        .modifier(AppSheetModifier(enabled: Launch.scenario == "e" && router.name == "main" && title == router.rootTitle))
    }
}

/// E: app code presenting its own SwiftUI sheet from a screen inside a Waypoint stack.
struct AppSheetModifier: ViewModifier {
    let enabled: Bool
    @State private var sheet = AppSheet.shared

    func body(content: Content) -> some View {
        if enabled {
            content.sheet(isPresented: $sheet.isShown, onDismiss: {
                ForeignWatch.shared.foreignClosedAt = Date()
                SpikeLog.shared.note("app sheet onDismiss")
            }) {
                VStack(spacing: 20) {
                    Text("App's own sheet").accessibilityIdentifier("appsheet")
                    Button("Close app sheet") { sheet.isShown = false }.accessibilityIdentifier("appsheet.close")
                }
            }
        } else {
            content
        }
    }
}

/// A: a SwiftUI destination with its own toolbar button, to check bars in both renderers.
struct ProductScreen: View {
    let router: StackRouter
    let route: ProductRoute

    var body: some View {
        SpikeScreen(router: router, title: route.title)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Share") { SpikeLog.shared.note("share tapped \(route.title)") }
                        .accessibilityIdentifier("toolbar.share")
                }
            }
    }
}

struct ActionGrid: View {
    let router: StackRouter

    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())]) {
            ForEach(SpikeAction.all) { action in
                Button(action.id) { action.run(router) }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier(action.id)
            }
        }
    }
}

struct DebugState: View {
    var body: some View {
        let log = SpikeLog.shared
        VStack(alignment: .leading) {
            Text(Roots.summary).accessibilityIdentifier("state")
            Text("notes: " + log.notes.suffix(8).joined(separator: " | ")).accessibilityIdentifier("notes")
        }
        .font(.caption2.monospaced())
    }
}

struct UIKitStack: UIViewControllerRepresentable {
    let router: StackRouter
    func makeUIViewController(context: Context) -> StackNavigationController { StackNavigationController(router: router) }
    func updateUIViewController(_ controller: StackNavigationController, context: Context) { }
}

// MARK: A, a UIKit controller as a SwiftUI destination

/// Hosts a `UIViewController` as a destination inside `NavigationStack`.
///
/// `-rawBridge` uses a bare `UIViewControllerRepresentable`, which is what an app writes by hand.
/// The default copies the controller's title and right bar button items into SwiftUI's bar, since
/// NavigationStack never reads a child controller's `navigationItem`.
struct ControllerScreen: View {
    let title: String
    let make: @MainActor () -> UIViewController
    @State private var controller: UIViewController?

    var body: some View {
        let hosted = controller ?? make()
        let representable = ControllerRepresentable(controller: hosted)
            .ignoresSafeArea(.container, edges: .bottom)
            .onAppear {
                if controller == nil { controller = hosted }
                SpikeLog.shared.didAppear(title)
            }
        if Launch.flag("rawBridge") {
            representable
        } else {
            representable
                .navigationTitle(hosted.navigationItem.title ?? hosted.title ?? "")
                .toolbar {
                    ForEach(Array((hosted.navigationItem.rightBarButtonItems ?? []).enumerated()), id: \.offset) { _, item in
                        ToolbarItem(placement: .topBarTrailing) {
                            Button(item.title ?? "") {
                                // Run the item's own action, so the legacy controller code is unchanged.
                                if let action = item.primaryAction {
                                    action.performWithSender(nil, target: nil)
                                } else if let target = item.target, let selector = item.action {
                                    _ = target.perform(selector, with: item)
                                }
                            }
                            .accessibilityIdentifier("toolbar.\(item.title ?? "")")
                        }
                    }
                }
        }
    }
}

struct ControllerRepresentable: UIViewControllerRepresentable {
    let controller: UIViewController
    func makeUIViewController(context: Context) -> UIViewController { controller }
    func updateUIViewController(_ controller: UIViewController, context: Context) { }
}

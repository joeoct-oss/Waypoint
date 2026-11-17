import SwiftUI
import UIKit

@main
struct ProposalSpikeApp: App {
    @State private var services = AppServices()

    var body: some Scene {
        WindowGroup(id: "main") {
            switch Launch.scenario {
            case "d":
                if Launch.flag("eagerState") {
                    EagerWaypointRoot(WindowCoordinator(services: services)) { coordinator in
                        WindowScreen(coordinator: coordinator, services: services)
                    }
                } else {
                    WaypointRoot(WindowCoordinator(services: services)) { coordinator in
                        WindowScreen(coordinator: coordinator, services: services)
                    }
                }
            case "a":
                ControllerRoot(make: makeScenarioARoot).ignoresSafeArea()
            default:
                // E and F: one stack in the chosen renderer at the window root.
                switch Launch.renderer {
                case .swiftUI:
                    StackView(router: Roots.main)
                case .uiKit:
                    UIKitStack(router: Roots.main).ignoresSafeArea()
                }
            }
        }
    }
}

/// Puts a UIKit root controller in the SwiftUI window.
struct ControllerRoot: UIViewControllerRepresentable {
    let make: @MainActor () -> UIViewController
    func makeUIViewController(context: Context) -> UIViewController { make() }
    func updateUIViewController(_ controller: UIViewController, context: Context) { }
}

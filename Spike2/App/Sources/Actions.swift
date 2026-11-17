import Foundation
import Observation

/// The buttons every spike screen shows, shared by the SwiftUI and UIKit screens.
@MainActor
struct SpikeAction: Identifiable {
    let id: String
    let run: (StackRouter) -> Void

    static var all: [SpikeAction] {
        switch Launch.scenario {
        case "e": stack + foreign
        case "f": stack + alerts
        default: stack
        }
    }

    static let stack: [SpikeAction] = [
        SpikeAction(id: "pushNext") { $0.push(LetterRoute(letter: "B\($0.path.count)")) },
        SpikeAction(id: "pushProduct") { $0.push(ProductRoute(id: $0.path.count)) },
        SpikeAction(id: "pushLegacy") { $0.push(LegacyRoute(id: $0.path.count)) },
        SpikeAction(id: "pop") { $0.pop() },
        SpikeAction(id: "popToRoot") { $0.popToRoot() },
        SpikeAction(id: "presentSwiftUI") { $0.present(.swiftUI) },
        SpikeAction(id: "presentUIKit") { $0.present(.uiKit) },
        SpikeAction(id: "dismissSheet") { _ in Roots.main.dismiss() },
        SpikeAction(id: "clearLog") { _ in SpikeLog.shared.clear() },
    ]

    /// E: foreign presentations, and a "link" that presents a Waypoint sheet while one is up.
    static let foreign: [SpikeAction] = [
        SpikeAction(id: "share") { _ in ForeignActions.share() },
        SpikeAction(id: "sdkSheet") { _ in ForeignActions.sdkSheet(fullScreen: false) },
        SpikeAction(id: "sdkCover") { _ in ForeignActions.sdkSheet(fullScreen: true) },
        SpikeAction(id: "appAlert") { _ in ForeignActions.appAlert() },
        SpikeAction(id: "safari") { _ in ForeignActions.safari() },
        SpikeAction(id: "systemAlert") { _ in ForeignActions.systemAlert() },
        SpikeAction(id: "swiftuiSheet") { _ in AppSheet.shared.isShown = true },
        // The link lands 1.5 s later, while the foreign screen is up.
        SpikeAction(id: "linkSoon") { _ in
            later(1500) {
                SpikeLog.shared.note("link arrives: present sheet on main; windows: \(ForeignWatch.describeWindows())")
                Roots.main.present(Launch.renderer)
            }
        },
    ]

    /// F: alerts against sheet dismissals.
    static let alerts: [SpikeAction] = [
        SpikeAction(id: "alertNow") { _ in Roots.main.alert = SpikeAlert(title: "Delete draft?", buttons: ["Delete", "Cancel"]) },
        // Same turn: the sheet is dismissed and the root flow asks for an alert.
        SpikeAction(id: "dismissAndAlert") { _ in
            Roots.main.dismiss()
            Roots.main.alert = SpikeAlert(title: "Saved", buttons: ["OK"])
        },
        // The alert lands 150 ms into the dismissal animation.
        SpikeAction(id: "dismissThenAlertSoon") { _ in
            Roots.main.dismiss()
            later(150) { Roots.main.alert = SpikeAlert(title: "Saved", buttons: ["OK"]) }
        },
        // The root flow asks for an alert while its sheet stays up.
        SpikeAction(id: "alertUnderSheet") { _ in Roots.main.alert = SpikeAlert(title: "Root alert", buttons: ["OK"]) },
        // An alert is up; 1 s later a link closes it, sets a path and presents a sheet in one change.
        SpikeAction(id: "alertThenLink") { _ in
            Roots.main.alert = SpikeAlert(title: "Delete draft?", buttons: ["Delete", "Cancel"])
            later(1000) {
                SpikeLog.shared.note("link arrives over alert")
                Roots.main.alert = nil
                Roots.main.path = [AnyRoute(LetterRoute(letter: "B")), AnyRoute(LetterRoute(letter: "C"))]
                Roots.main.present(Launch.renderer)
            }
        },
    ]

    static func later(_ milliseconds: Int, _ change: @escaping @MainActor () -> Void) {
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(milliseconds))
            change()
        }
    }
}

/// E: a sheet that app code presents with SwiftUI's own `.sheet`, outside Waypoint.
@MainActor
@Observable
final class AppSheet {
    static let shared = AppSheet()
    var isShown = false
}

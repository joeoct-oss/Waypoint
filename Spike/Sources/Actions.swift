import Foundation

/// The buttons every spike screen shows, shared by the SwiftUI and UIKit screens.
@MainActor
struct SpikeAction: Identifiable {
    let id: String
    let run: (StackRouter) -> Void

    static let all: [SpikeAction] = [
        SpikeAction(id: "pushNext") { router in
            let next = Character(UnicodeScalar(router.lastLetter.unicodeScalars.first!.value + 1)!)
            router.push(LetterRoute(letter: String(next)))
        },
        SpikeAction(id: "pushToE") { router in
            let start = router.lastLetter.unicodeScalars.first!.value + 1
            let end = Character("E").unicodeScalars.first!.value
            guard start <= end else { return }
            router.pushMany((start...end).map { LetterRoute(letter: String(Character(UnicodeScalar($0)!))) })
        },
        SpikeAction(id: "pushProduct") { $0.push(ProductRoute(id: $0.path.count)) },
        SpikeAction(id: "pop") { $0.pop() },
        SpikeAction(id: "popToB") { $0.popTo(LetterRoute(letter: "B")) },
        SpikeAction(id: "popToRoot") { $0.popToRoot() },
        SpikeAction(id: "presentSwiftUI") { $0.present(.swiftUI) },
        SpikeAction(id: "presentUIKit") { $0.present(.uiKit) },
        SpikeAction(id: "linkB") { _ in AppRouter.shared.open(URL(string: "spike://open?tab=b&path=B,C,D")!) },
        SpikeAction(id: "linkA") { _ in AppRouter.shared.open(URL(string: "spike://open?tab=a&path=B,C")!) },
        SpikeAction(id: "clearLog") { _ in AppRouter.shared.clearLog() },
    ]
}

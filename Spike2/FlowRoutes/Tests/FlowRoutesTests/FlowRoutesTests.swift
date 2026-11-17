// Throwaway spike C tests. Each prints a FINDING line.

import Foundation
import Testing
import WaypointCore
@testable import FlowRoutes

struct HomeRoute: Route { }
struct AddressStepRoute: Route { }
struct PaymentStepRoute: Route { }
struct ReceiptRoute: Route { }

struct CheckoutRoute: FlowRoute {
    typealias Result = String
    let cartID: Int
}

struct AddressBookRoute: FlowRoute {
    typealias Result = String
}

/// App-wide services the factories capture. Never in a route.
@MainActor
final class Services {
    var orders: [String] = []
    var cancelledCheckouts = 0
    var builtCarts: [Int] = []
}

@MainActor
final class AppCoordinator: Coordinator {
    init(router: StackRouter, services: Services) {
        super.init(router: router, route: nil)
        onResult(CheckoutRoute.self) { result in
            switch result {
            case .finished(let order): services.orders.append(order)
            case .cancelled: services.cancelledCheckouts += 1
            }
        }
    }
}

@MainActor
final class CheckoutCoordinator: Coordinator {
    let cartID: Int
    var pickedAddress: String?

    init(route: CheckoutRoute, router: StackRouter, services: Services) {
        cartID = route.cartID
        services.builtCarts.append(route.cartID)
        super.init(router: router, route: AnyRoute(route))
        onResult(AddressBookRoute.self) { [weak self] result in
            if case .finished(let address) = result {
                self?.pickedAddress = address
            }
        }
    }
}

@MainActor
final class AddressBookCoordinator: Coordinator { }

@MainActor
func makeHost(_ services: Services, root: StackRouter = StackRouter(root: HomeRoute())) -> FlowHost {
    let host = FlowHost(root: root) { AppCoordinator(router: $0, services: services) }
    host.flow(CheckoutRoute.self) { route, router in
        CheckoutCoordinator(route: route, router: router, services: services)
    }
    host.flow(AddressBookRoute.self) { route, router in
        AddressBookCoordinator(router: router, route: AnyRoute(route))
    }
    host.screen(HomeRoute.self)
    host.screen(AddressStepRoute.self)
    host.screen(PaymentStepRoute.self)
    host.screen(ReceiptRoute.self)
    return host
}

func finding(_ text: String) {
    print("FINDING \(text)")
}

@MainActor
@Suite struct FlowRouteSpike {
    @Test func presentBuildsCoordinatorFromRoute() {
        let services = Services()
        let host = makeHost(services)
        host.appCoordinator.present(CheckoutRoute(cartID: 7))
        let checkout = host.coordinator(for: CheckoutRoute.self) as? CheckoutCoordinator
        #expect(checkout?.cartID == 7)
        #expect(checkout?.router === host.rootRouter.presented)
        finding("present: built=\(host.log) tree=\(host.rootRouter.debugTree(revealingPrivateValues: true))")
    }

    @Test func finishReachesHandler() {
        let services = Services()
        let host = makeHost(services)
        host.appCoordinator.present(CheckoutRoute(cartID: 7))
        host.coordinator(for: CheckoutRoute.self)?.finish(CheckoutRoute.self, with: "order-1")
        #expect(services.orders == ["order-1"])
        #expect(host.rootRouter.presented == nil)
        #expect(host.liveFlowCount == 0)
        finding("finish: log=\(host.log)")
    }

    @Test func awaitReachesAwaiter() async {
        let services = Services()
        let host = makeHost(services)
        let task = Task { await host.appCoordinator.presentAndWait(CheckoutRoute(cartID: 3)) }
        while host.coordinator(for: CheckoutRoute.self) == nil {
            await Task.yield()
        }
        host.coordinator(for: CheckoutRoute.self)?.finish(CheckoutRoute.self, with: "order-3")
        let value = await task.value
        guard case .finished(let order) = value else {
            Issue.record("expected finished")
            return
        }
        #expect(order == "order-3")
        #expect(services.orders.isEmpty)
        finding("await: log=\(host.log)")
    }

    @Test func linkBuildsFlowAndItsStep() {
        let services = Services()
        let host = makeHost(services)
        let plan = FlowHost.Snapshot(
            path: [],
            presentedRoute: AnyRoute(CheckoutRoute(cartID: 9)),
            presentedStyle: .sheet,
            presented: [FlowHost.Snapshot(path: [AnyRoute(AddressStepRoute())])]
        )
        let outcome = host.open(plan)
        let checkout = host.coordinator(for: CheckoutRoute.self) as? CheckoutCoordinator
        #expect(checkout?.cartID == 9)
        #expect(host.rootRouter.presented?.state.path == [AnyRoute(AddressStepRoute())])
        finding("link: outcome=\(outcome) tree=\(host.rootRouter.debugTree(revealingPrivateValues: true)) log=\(host.log)")
    }

    @Test func restoreRebuildsFlowsAndResultsReachHandlers() throws {
        let services = Services()
        let host = makeHost(services)
        host.appCoordinator.present(CheckoutRoute(cartID: 5))
        let checkout = try #require(host.coordinator(for: CheckoutRoute.self))
        checkout.router.push(AddressStepRoute())
        checkout.push(flow: AddressBookRoute())
        #expect(host.liveFlowCount == 2)

        let data = try host.encode(host.snapshot())
        finding("restore: saved \(data.count) bytes: \(String(decoding: data, as: UTF8.self))")

        // The app is killed. A new process builds new services, a new root and decodes the save.
        let newServices = Services()
        let newHost = makeHost(newServices, root: StackRouter(root: HomeRoute()))
        newHost.restore(try newHost.decode(data), root: StackRouter(root: HomeRoute()))
        #expect(newHost.liveFlowCount == 2)
        #expect(newServices.builtCarts == [5])
        finding("restore: rebuilt tree=\(newHost.rootRouter.debugTree(revealingPrivateValues: true)) log=\(newHost.log)")

        // The pushed address book finishes: its result reaches the rebuilt checkout coordinator.
        newHost.coordinator(for: AddressBookRoute.self)?.finish(AddressBookRoute.self, with: "Home")
        let rebuilt = try #require(newHost.coordinator(for: CheckoutRoute.self) as? CheckoutCoordinator)
        #expect(rebuilt.pickedAddress == "Home")
        #expect(rebuilt.router.state.path == [AnyRoute(AddressStepRoute())])

        // Checkout finishes: the rebuilt app coordinator's handler gets it.
        rebuilt.finish(CheckoutRoute.self, with: "order-5")
        #expect(newServices.orders == ["order-5"])
        #expect(newHost.rootRouter.presented == nil)
        finding("restore: after finishes log=\(newHost.log)")
    }

    @Test func awaitingCallerLostOnRestoreFallsBackToHandler() async throws {
        let services = Services()
        let host = makeHost(services)
        // A caller awaits; the app is then killed, so the await never returns.
        Task { _ = await host.appCoordinator.presentAndWait(CheckoutRoute(cartID: 8)) }
        while host.coordinator(for: CheckoutRoute.self) == nil {
            await Task.yield()
        }
        let data = try host.encode(host.snapshot())

        let newServices = Services()
        let newHost = makeHost(newServices)
        newHost.restore(try newHost.decode(data), root: StackRouter(root: HomeRoute()))
        newHost.coordinator(for: CheckoutRoute.self)?.finish(CheckoutRoute.self, with: "order-8")
        #expect(newServices.orders == ["order-8"])
        finding("await-then-restore: log=\(newHost.log)")
    }

    @Test func userDismissDeliversCancelled() {
        let services = Services()
        let host = makeHost(services)
        host.appCoordinator.present(CheckoutRoute(cartID: 1))
        // The renderer reports a swipe down as a dismiss on the presenting router.
        host.rootRouter.dismiss()
        host.sync()
        #expect(services.cancelledCheckouts == 1)
        #expect(host.liveFlowCount == 0)
        finding("user dismiss: log=\(host.log)")
    }

    @Test func linkReplacingAnOpenFlowCancelsIt() {
        let services = Services()
        let host = makeHost(services)
        host.appCoordinator.present(CheckoutRoute(cartID: 1))
        host.open(FlowHost.Snapshot(path: [], presentedRoute: AnyRoute(CheckoutRoute(cartID: 2)), presentedStyle: .sheet))
        #expect(services.cancelledCheckouts == 1)
        #expect((host.coordinator(for: CheckoutRoute.self) as? CheckoutCoordinator)?.cartID == 2)
        // The same link again keeps the live coordinator: a link is not a rebuild.
        host.open(FlowHost.Snapshot(path: [], presentedRoute: AnyRoute(CheckoutRoute(cartID: 2)), presentedStyle: .sheet))
        finding("link replace: carts built=\(services.builtCarts) cancelled=\(services.cancelledCheckouts) log=\(host.log)")
    }

    @Test func finishTwiceIsIgnored() {
        let services = Services()
        let host = makeHost(services)
        host.appCoordinator.present(CheckoutRoute(cartID: 1))
        let checkout = host.coordinator(for: CheckoutRoute.self)
        checkout?.finish(CheckoutRoute.self, with: "a")
        checkout?.finish(CheckoutRoute.self, with: "b")
        #expect(services.orders == ["a"])
        finding("finish twice: log=\(host.log)")
    }

    @Test func popBelowPushedFlowCancelsIt() throws {
        let services = Services()
        let host = makeHost(services)
        host.appCoordinator.present(CheckoutRoute(cartID: 1))
        let checkout = try #require(host.coordinator(for: CheckoutRoute.self))
        checkout.push(flow: AddressBookRoute())
        checkout.router.push(PaymentStepRoute())
        // Swipe back twice: the address book flow's route leaves the path.
        checkout.router.popToRoot()
        host.sync()
        #expect(host.liveFlowCount == 1)
        finding("pop below pushed flow: log=\(host.log)")
    }
}

//
//  AppServices.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import Waypoint

// The one container: the services every window shares, made once by the `App` and handed to each
// window's app coordinator. It holds the product catalog, the local store, the session, the saved
// addresses, the auth service, and the navigation configuration each stack router gets, which logs
// to the unified log, logs navigation issues to `issues` and every call to `events`, and counts in
// `issues` each call that failed with no fallback to recover it (`onNavigationFailure`). When a UI
// test links to a route with no destination, the configuration's registry lists that route, so the
// router lets the push through and the stack shows its missing-destination screen.
//
// Each feature's dependency struct comes from one method here, so a feature's needs are listed in
// one place and a test passes fakes the same way. The coordinators still take their services one
// by one until they move onto these structs (planning #313, planning #424). Every service here
// lives as long as the app; what lives for one flow or one screen never goes in here. `clearAll()`
// removes everything the app keeps, signs the reader out and puts the sample addresses back.
final class AppServices {
    let catalog: any ProductCatalog
    let store: LocalStore
    let session: Session
    let addresses: AddressBook
    let auth: any AuthService
    let issues: IssueLog
    let events: EventLog
    let navigation: NavigationConfiguration

    init(
        launch: LaunchOptions,
        store: LocalStore = LocalStore(),
        catalog: any ProductCatalog = SampleCatalog()
    ) {
        if launch.clearsData {
            store.clearAll()
        }
        let session = Session(store: store)
        if launch.signsIn {
            session.signIn(.sample)
        }
        self.catalog = catalog
        self.store = store
        self.session = session
        addresses = AddressBook(store: store)
        auth = MockAuthService(store: store)
        let issues = IssueLog()
        let events = EventLog()
        let logging = Self.makeLogging(issues: issues, events: events)
        self.issues = issues
        self.events = events
        navigation = NavigationConfiguration(
            logging: logging,
            registry: Self.makeRegistry(for: launch),
            onNavigationFailure: { issues.recordFailure($0) }
        )
    }

    // Debug builds write to the unified log from `.info`, with route values, so Xcode's console and
    // Console.app show the reader's journey: one box per change. The routers log from `.debug`, so
    // the Lab's event log also gets each call's own line (push, skip, queue, ignore). Set the
    // system level to `.debug` to add those lines, and a box with every field of each visit, to the
    // console. Release builds keep the defaults: `.notice` and above, with route values hidden.
    private static func makeLogging(issues: IssueLog, events: EventLog) -> LogConfiguration {
        #if DEBUG
            let handler = AppLogHandler(systemLevel: .info, issues: issues, events: events)
            return LogConfiguration(
                handler: handler,
                minimumLevel: .debug,
                revealsPrivateValues: true
            )
        #else
            let handler = AppLogHandler(systemLevel: .notice, issues: issues, events: events)
            return LogConfiguration(handler: handler)
        #endif
    }

    private static func makeRegistry(for launch: LaunchOptions) -> RouteRegistry {
        guard launch.linksToMissingDestination else {
            return .strict
        }
        return RouteRegistry.strict.registering(ProductReviewsRoute.self)
    }

    // What Shop and Search use. `launch` is the window's, so its link settings reach the products
    // stacks.
    func productsDependencies(
        gate: any SheetAccountGating,
        launch: LaunchOptions
    ) -> ProductsDependencies {
        let products = ProductsNavigation(
            configuration: navigation,
            usesSystemLinks: launch.usesSystemLinks,
            linksToMissingDestination: launch.linksToMissingDestination
        )
        return ProductsDependencies(
            catalog: catalog,
            store: store,
            gate: gate,
            navigation: products,
            cartScreen: { FeatureScreens.cart($0) }
        )
    }

    // What the Cart tab and checkout use.
    func cartDependencies(gate: any AccountGating) -> CartDependencies {
        CartDependencies(
            catalog: catalog,
            store: store,
            addresses: addresses,
            gate: gate
        )
    }

    // What the Account tab uses, the Navigation Lab's included. `describeTree` gives the window's
    // navigation tree as text, for the Lab's tree tool.
    func accountDependencies(
        gate: AccountGate,
        rules: NavigationRules,
        describeTree: @escaping () -> String
    ) -> AccountDependencies {
        let lab = labDependencies()
        return AccountDependencies(
            catalog: catalog,
            session: session,
            store: store,
            addresses: addresses,
            gate: gate,
            rules: rules,
            issues: issues,
            events: events,
            lab: lab,
            describeTree: describeTree,
            wishlistScreen: { FeatureScreens.wishlist($0) }
        )
    }

    // What the accounts sheet uses: sign in, create account and reset password.
    func authDependencies() -> AuthDependencies {
        AuthDependencies(
            session: session,
            service: auth
        )
    }

    // What the Navigation Lab's demo flows use.
    func labDependencies() -> LabDependencies {
        LabDependencies(
            catalog: catalog,
            navigation: navigation
        )
    }

    func clearAll() {
        store.clearAll()
        session.signOut()
        addresses.reload()
    }
}

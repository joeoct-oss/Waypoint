//
//  AppServices.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import Waypoint

// The services every window shares: the local store, the session, the saved addresses, the auth
// service, and the navigation configuration each stack router gets, which logs to the unified log,
// logs navigation issues to `issues` and every call to `events`, and counts in `issues` each call
// that failed with no fallback to recover it (`onNavigationFailure`). When a UI test links to a
// route with no destination, the configuration's registry lists that route, so the router lets the
// push through and the stack shows its missing-destination screen. The `App` makes them once and
// hands them to each window's app coordinator. `clearAll()` removes everything the app keeps, signs
// the reader out and puts the sample addresses back.
@MainActor
final class AppServices {
    let store: LocalStore
    let session: Session
    let addresses: AddressBook
    let auth: any AuthService
    let issues: IssueLog
    let events: EventLog
    let navigation: NavigationConfiguration

    init(launch: LaunchOptions) {
        let store = LocalStore()
        if launch.clearsData {
            store.clearAll()
        }
        let session = Session(store: store)
        if launch.signsIn {
            session.signIn(.sample)
        }
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

    func clearAll() {
        store.clearAll()
        session.signOut()
        addresses.reload()
    }
}

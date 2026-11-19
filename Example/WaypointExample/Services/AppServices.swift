//
//  AppServices.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import WaypointCore

// The services every window shares: the local store, the session, the saved addresses, the auth
// service, and the navigation configuration each stack router gets, which logs navigation issues to
// `issues`. When a UI test links to a route with no destination, the configuration's registry lists
// that route, so the router lets the push through and the stack shows its missing-destination
// screen. The `App` makes them once and hands them to each window's app coordinator. `clearAll()`
// removes everything the app keeps, signs the reader out and puts the sample addresses back.
@MainActor
final class AppServices {
    let store: LocalStore
    let session: Session
    let addresses: AddressBook
    let auth: any AuthService
    let issues: IssueLog
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
        let logging = LogConfiguration.default.withHandler(IssueLogHandler(issues: issues))
        self.issues = issues
        navigation = NavigationConfiguration(
            logging: logging,
            registry: Self.makeRegistry(for: launch)
        )
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

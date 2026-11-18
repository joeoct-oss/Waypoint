//
//  AppServices.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import WaypointCore

// The services every window shares: the local store, the session, the auth service, and the
// navigation configuration each stack router gets, which logs navigation issues to `issues`. The
// `App` makes them once and hands them to each window's app coordinator. `clearAll()` removes
// everything the app keeps and signs the reader out.
@MainActor
final class AppServices {
    let store: LocalStore
    let session: Session
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
        auth = MockAuthService(store: store)
        let issues = IssueLog()
        let logging = LogConfiguration.default.withHandler(IssueLogHandler(issues: issues))
        self.issues = issues
        navigation = NavigationConfiguration(logging: logging)
    }

    func clearAll() {
        store.clearAll()
        session.signOut()
    }
}

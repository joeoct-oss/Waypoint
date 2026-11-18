//
//  AppServices.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//


// The services every window shares: the local store, the session and the auth service. The `App`
// makes them once and hands them to each window's app coordinator. `clearAll()` removes everything
// the app keeps and signs the reader out.
@MainActor
final class AppServices {
    let store: LocalStore
    let session: Session
    let auth: any AuthService

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
    }

    func clearAll() {
        store.clearAll()
        session.signOut()
    }
}

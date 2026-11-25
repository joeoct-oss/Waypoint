//
//  AuthDependencies.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import ExampleServices

// What the accounts sheet uses, from `AppServices.authDependencies()`: the session it signs in, and
// the auth service that checks the email and password.
package struct AuthDependencies {
    package let session: Session
    package let service: any AuthService

    package init(
        session: Session,
        service: any AuthService
    ) {
        self.session = session
        self.service = service
    }
}

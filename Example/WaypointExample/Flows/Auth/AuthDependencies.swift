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
struct AuthDependencies {
    let session: Session
    let service: any AuthService
}

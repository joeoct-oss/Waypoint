//
//  AppRoot.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

// The root the app shows: the splash while it starts, the accounts flow (welcome, sign in, create
// account), or the main tabs. Each flow root carries the coordinator made for it, so switching
// roots drops the old flow's state with it.
enum AppRoot {
    case splash
    case auth(AuthCoordinator)
    case main(MainCoordinator)
}

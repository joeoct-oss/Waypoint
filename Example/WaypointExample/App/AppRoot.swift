//
//  AppRoot.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <52625092+JoeOCT91@users.noreply.github.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

// The root the app shows: the splash while it starts, the sign-in flow, or the main tabs. Each flow root
// carries the coordinator made for it, so switching roots drops the old flow's state with it.
enum AppRoot {
    case splash
    case auth(AuthCoordinator)
    case main(MainCoordinator)
}

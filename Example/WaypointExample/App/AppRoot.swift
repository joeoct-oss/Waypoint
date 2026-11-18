//
//  AppRoot.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

// The root the app shows: the splash while it starts, then the main tabs, which guests and
// signed-in readers share. The main root carries the coordinator made for it, so starting over
// after Clear all data drops the old tabs' state with it.
enum AppRoot {
    case splash
    case main(MainCoordinator)
}

//
//  Binding+Reading.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import SwiftUI

extension Binding {
    // A binding for a coordinator's state. The view reads `value` in its `body`, which is what
    // makes it redraw when the coordinator changes it, and `writing` hands the system's own changes
    // back, such as a pop from the back button or a sheet dismissed by a swipe.
    init(
        reading value: Value,
        writing: @escaping (Value) -> Void
    ) {
        self.init(
            get: { value },
            set: { writing($0) }
        )
    }
}

//
//  ResultLog.swift
//  ExampleTestSupport
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import Waypoint

// The results a parent flow got from its child flow, oldest first.
package final class ResultLog<Value: Sendable> {
    // `var` because each ended flow adds its result. Only `record(_:)` changes it.
    package private(set) var values: [FlowResult<Value>] = []

    package init() { }

    package func record(_ result: FlowResult<Value>) {
        values.append(result)
    }
}

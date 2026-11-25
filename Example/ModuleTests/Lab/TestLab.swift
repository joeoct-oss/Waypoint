//
//  TestLab.swift
//  ExampleLabTests
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import ExampleLab
import ExampleStore

// A Lab factory for a test: the sample catalog and the default navigation configuration.
enum TestLab {
    static func makeFactory() -> LabFactory {
        LabFactory(
            dependencies: LabDependencies(
                catalog: SampleCatalog(),
                navigation: .default
            )
        )
    }
}

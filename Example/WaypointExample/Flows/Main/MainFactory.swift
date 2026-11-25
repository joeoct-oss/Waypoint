//
//  MainFactory.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import Waypoint

// Builds the main tabs from the app's services: the main coordinator, its tab router, the account
// gate and the navigation rules, and each tab's coordinator from its feature's dependency struct,
// through that feature's factory. The main coordinator passes in what each tab reports, so moving
// between tabs stays in the main coordinator.
struct MainFactory {
    private let services: AppServices
    private let launch: LaunchOptions

    init(
        services: AppServices,
        launch: LaunchOptions
    ) {
        self.services = services
        self.launch = launch
    }

    // The main tabs. Clear all data runs `onClearAllData`.
    func makeCoordinator(onClearAllData: @escaping () -> Void) -> MainCoordinator {
        MainCoordinator(
            factory: self,
            issues: services.issues,
            onClearAllData: onClearAllData
        )
    }

    // The tabs around one stack every tab shares: Shop first, or Account for a launch into the
    // Lab. The tab bar pops nothing on a second tap, as before every tab ran on Waypoint.
    func makeTabRouter() -> TabRouter<MainTab> {
        let tabs = TabRouter(
            selection: launch.opensLab ? MainTab.account : .shop,
            stacks: .shared,
            popsToRootOnReselect: false,
            configuration: services.navigation
        )
        tabs.setPresentationDefaults(AppSheets.defaults)
        return tabs
    }

    // The gate that presents the accounts sheet over `tabs` when an action needs an account.
    func makeGate(tabs: TabRouter<MainTab>) -> AccountGate {
        AccountGate(
            session: services.session,
            factory: AuthFactory(dependencies: services.authDependencies()),
            tabs: tabs
        )
    }

    func makeRules(tabs: TabRouter<MainTab>) -> NavigationRules {
        NavigationRules(tabs: tabs)
    }

    // Shop, which plays the launch's product steps the first time it appears.
    func makeShop(
        gate: AccountGate,
        onAddToCart: @escaping (Product) -> Void,
        cart: ProductsCart
    ) -> ProductsCoordinator {
        makeProductsFactory(gate: gate).makeCoordinator(
            start: .browse,
            launchSteps: launch.shopSteps,
            onAddToCart: onAddToCart,
            cart: cart
        )
    }

    func makeSearch(
        gate: AccountGate,
        onAddToCart: @escaping (Product) -> Void,
        cart: ProductsCart
    ) -> ProductsCoordinator {
        makeProductsFactory(gate: gate).makeCoordinator(
            start: .search,
            launchSteps: .none,
            onAddToCart: onAddToCart,
            cart: cart
        )
    }

    // The Cart tab. Keep shopping runs `onShopMore`.
    func makeCart(
        gate: AccountGate,
        onShopMore: @escaping () -> Void
    ) -> CartCoordinator {
        CartFactory(dependencies: services.cartDependencies(gate: gate))
            .makeCoordinator(onShopMore: onShopMore)
    }

    // The Account tab, with the Lab. `describeTree` gives the window's navigation tree as text, for
    // the Lab's tree tool, and Clear all data runs `onClearAllData`.
    func makeAccount(
        gate: AccountGate,
        rules: NavigationRules,
        describeTree: @escaping () -> String,
        onClearAllData: @escaping () -> Void
    ) -> AccountCoordinator {
        let dependencies = services.accountDependencies(
            gate: gate,
            rules: rules,
            describeTree: describeTree
        )
        return AccountFactory(dependencies: dependencies).makeCoordinator(
            launch: launch,
            onClearAllData: onClearAllData
        )
    }

    private func makeProductsFactory(gate: AccountGate) -> ProductsFactory {
        ProductsFactory(dependencies: services.productsDependencies(gate: gate, launch: launch))
    }
}

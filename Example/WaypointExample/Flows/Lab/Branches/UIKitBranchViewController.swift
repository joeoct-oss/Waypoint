//
//  UIKitBranchViewController.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import UIKit

// The UIKit branch: the same five flows as the SwiftUI branch, in a system inset-grouped table. The
// controller reports the entry the reader picks, and the app coordinator opens it. The table
// scrolls under the system bars, which are Liquid Glass from iOS 26.
//
// Conformances:
// - `UITableViewDataSource`, so the table asks this controller for one row per flow.
final class UIKitBranchViewController: UIViewController, UITableViewDataSource {
    private let onSelect: (FlowEntry) -> Void

    init(onSelect: @escaping (FlowEntry) -> Void) {
        self.onSelect = onSelect
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("UIKitBranchViewController is built in code")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Palette.background.uiColor
        let tableView = makeTableView()
        view.addSubview(tableView)
        pin(tableView, to: view)
    }

    nonisolated private static func applyButtonFont(
        to attributes: AttributeContainer
    ) -> AttributeContainer {
        // `var` because the font is set on a copy of the incoming attributes.
        var styled = attributes
        styled.font = Typography.uiButton
        return styled
    }

    func tableView(
        _ tableView: UITableView,
        numberOfRowsInSection section: Int
    ) -> Int {
        ExampleFlow.allCases.count
    }

    func tableView(
        _ tableView: UITableView,
        cellForRowAt indexPath: IndexPath
    ) -> UITableViewCell {
        let flow = ExampleFlow.allCases[indexPath.row]
        return makeCell(for: flow)
    }

    private func makeTableView() -> UITableView {
        let tableView = UITableView(frame: .zero, style: .insetGrouped)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.backgroundColor = Palette.background.uiColor
        tableView.allowsSelection = false
        tableView.dataSource = self
        return tableView
    }

    // Five rows that are all on screen, so each cell is made fresh instead of dequeued.
    private func makeCell(for flow: ExampleFlow) -> UITableViewCell {
        let cell = UITableViewCell()
        cell.backgroundColor = Palette.surface.uiColor
        let row = makeRow(for: flow)
        row.translatesAutoresizingMaskIntoConstraints = false
        cell.contentView.addSubview(row)
        pin(row, toMarginsOf: cell.contentView)
        return cell
    }

    private func makeRow(for flow: ExampleFlow) -> UIView {
        let header = makeHeader(for: flow)
        let buttons = makeButtons(for: flow)
        let parts = [
            header,
            buttons,
        ]
        let row = UIStackView(arrangedSubviews: parts)
        row.axis = .vertical
        row.spacing = Spacing.medium
        return row
    }

    private func makeHeader(for flow: ExampleFlow) -> UIView {
        let icon = makeIcon(for: flow)
        let titles = makeTitles(for: flow)
        let parts = [
            icon,
            titles,
        ]
        let header = UIStackView(arrangedSubviews: parts)
        header.spacing = Spacing.medium
        header.alignment = .center
        return header
    }

    private func makeIcon(for flow: ExampleFlow) -> UIView {
        let image = UIImage(systemName: flow.symbolName)
        let imageView = UIImageView(image: image)
        imageView.tintColor = Palette.brand.uiColor
        imageView.contentMode = .center
        imageView.backgroundColor = Palette.brandSubtle.uiColor
        imageView.layer.cornerRadius = Radius.field
        imageView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(textStyle: .title3)
        imageView.isAccessibilityElement = false
        let constraints = [
            imageView.widthAnchor.constraint(equalToConstant: Size.rowIcon),
            imageView.heightAnchor.constraint(equalToConstant: Size.rowIcon),
        ]
        NSLayoutConstraint.activate(constraints)
        return imageView
    }

    private func makeTitles(for flow: ExampleFlow) -> UIView {
        let title = UILabel()
        title.text = flow.title
        title.font = Typography.uiHeadline
        title.textColor = Palette.text.uiColor
        title.adjustsFontForContentSizeCategory = true
        let summary = UILabel()
        summary.text = flow.summary
        summary.font = Typography.uiFootnote
        summary.textColor = Palette.textTertiary.uiColor
        summary.numberOfLines = 0
        summary.adjustsFontForContentSizeCategory = true
        let labels = [
            title,
            summary,
        ]
        let titles = UIStackView(arrangedSubviews: labels)
        titles.axis = .vertical
        titles.spacing = 2
        return titles
    }

    private func makeButtons(for flow: ExampleFlow) -> UIView {
        let buttons = FlowKind.allCases.map { makeButton(for: flow, kind: $0) }
        let stack = UIStackView(arrangedSubviews: buttons)
        stack.spacing = Spacing.small
        stack.distribution = .fillEqually
        stack.isLayoutMarginsRelativeArrangement = true
        stack.directionalLayoutMargins = NSDirectionalEdgeInsets(
            top: 0,
            leading: Size.rowIcon + Spacing.medium,
            bottom: 0,
            trailing: 0
        )
        return stack
    }

    private func makeButton(
        for flow: ExampleFlow,
        kind: FlowKind
    ) -> UIButton {
        let entry = FlowEntry(
            branch: .uiKit,
            flow: flow,
            kind: kind
        )
        let action = UIAction(title: kind.buttonTitle) { [weak self] _ in
            self?.reportSelection(of: entry)
        }
        let button = UIButton(configuration: makeButtonConfiguration(for: kind), primaryAction: action)
        button.accessibilityIdentifier = Identifiers.entry(entry)
        button.heightAnchor.constraint(greaterThanOrEqualToConstant: Size.minimumTouchTarget).isActive = true
        return button
    }

    private func makeButtonConfiguration(for kind: FlowKind) -> UIButton.Configuration {
        // `var` because the configuration is built up one property at a time below.
        var configuration = UIButton.Configuration.tinted()
        configuration.baseForegroundColor = kind.tint.uiColor
        configuration.baseBackgroundColor = kind.tint.uiColor
        configuration.cornerStyle = .capsule
        configuration.buttonSize = .large
        configuration.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer(Self.applyButtonFont)
        return configuration
    }

    private func pin(
        _ subview: UIView,
        to container: UIView
    ) {
        let constraints = [
            subview.topAnchor.constraint(equalTo: container.topAnchor),
            subview.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            subview.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            subview.trailingAnchor.constraint(equalTo: container.trailingAnchor),
        ]
        NSLayoutConstraint.activate(constraints)
    }

    private func pin(
        _ subview: UIView,
        toMarginsOf container: UIView
    ) {
        let margins = container.layoutMarginsGuide
        let constraints = [
            subview.topAnchor.constraint(equalTo: margins.topAnchor),
            subview.bottomAnchor.constraint(equalTo: margins.bottomAnchor),
            subview.leadingAnchor.constraint(equalTo: margins.leadingAnchor),
            subview.trailingAnchor.constraint(equalTo: margins.trailingAnchor),
        ]
        NSLayoutConstraint.activate(constraints)
    }

    private func reportSelection(of entry: FlowEntry) {
        onSelect(entry)
    }
}

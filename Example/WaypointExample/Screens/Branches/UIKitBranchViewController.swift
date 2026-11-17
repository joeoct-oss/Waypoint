//
//  UIKitBranchViewController.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <52625092+JoeOCT91@users.noreply.github.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import UIKit

// The UIKit branch: the same five flows as the SwiftUI branch, built with UIKit views. The controller
// reports the entry the reader picks, and the app coordinator opens it.
final class UIKitBranchViewController: UIViewController {
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
        let scrollView = makeScrollView()
        view.addSubview(scrollView)
        pin(scrollView, to: view)
    }

    nonisolated private static func applyButtonFont(
        to attributes: AttributeContainer
    ) -> AttributeContainer {
        // `var` because the font is set on a copy of the incoming attributes.
        var styled = attributes
        styled.font = Typography.uiButton
        return styled
    }

    private func makeScrollView() -> UIScrollView {
        let card = makeCard()
        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.alwaysBounceVertical = true
        scrollView.addSubview(card)
        let content = scrollView.contentLayoutGuide
        let frame = scrollView.frameLayoutGuide
        let constraints = [
            card.topAnchor.constraint(equalTo: content.topAnchor),
            card.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -Spacing.large),
            card.leadingAnchor.constraint(equalTo: frame.leadingAnchor, constant: Spacing.large),
            card.trailingAnchor.constraint(equalTo: frame.trailingAnchor, constant: -Spacing.large),
        ]
        NSLayoutConstraint.activate(constraints)
        return scrollView
    }

    private func makeCard() -> UIView {
        let rows = ExampleFlow.allCases.map(makeRow(for:))
        let stack = UIStackView(arrangedSubviews: rows)
        stack.axis = .vertical
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.backgroundColor = Palette.surface.uiColor
        stack.layer.cornerRadius = Radius.card
        stack.layer.borderWidth = 1
        stack.layer.borderColor = Palette.line.uiColor.resolvedColor(with: traitCollection).cgColor
        stack.clipsToBounds = true
        return stack
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
        row.isLayoutMarginsRelativeArrangement = true
        row.directionalLayoutMargins = NSDirectionalEdgeInsets(
            top: Spacing.medium,
            leading: Spacing.medium + 2,
            bottom: Spacing.medium,
            trailing: Spacing.medium + 2
        )
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
        var configuration = UIButton.Configuration.plain()
        configuration.baseForegroundColor = kind.tint.uiColor
        configuration.background.backgroundColor = Palette.surface.uiColor
        configuration.background.strokeColor = Palette.line.uiColor
        configuration.background.strokeWidth = 1
        configuration.background.cornerRadius = Radius.field
        configuration.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer(Self.applyButtonFont)
        return configuration
    }

    private func pin(
        _ subview: UIView,
        to container: UIView
    ) {
        let constraints = [
            subview.topAnchor.constraint(equalTo: container.safeAreaLayoutGuide.topAnchor),
            subview.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            subview.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            subview.trailingAnchor.constraint(equalTo: container.trailingAnchor),
        ]
        NSLayoutConstraint.activate(constraints)
    }

    private func reportSelection(of entry: FlowEntry) {
        onSelect(entry)
    }
}

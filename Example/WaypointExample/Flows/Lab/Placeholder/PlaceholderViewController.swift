//
//  PlaceholderViewController.swift
//  WaypointExample
//
//  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
//  Copyright © 2026 Yousef Mohamed. MIT License.
//

import ExampleCatalog
import ExampleDesignSystem
import UIKit

// The UIKit placeholder for a flow: the same content as `PlaceholderView`, built with UIKit views.
package final class PlaceholderViewController: UIViewController {
    private let entry: FlowEntry

    package init(entry: FlowEntry) {
        self.entry = entry
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    package required init?(coder: NSCoder) {
        fatalError("PlaceholderViewController is built in code")
    }

    package override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Palette.background.uiColor
        view.accessibilityIdentifier = Identifiers.placeholder(entry)
        let content = makeContent()
        view.addSubview(content)
        center(content, in: view)
    }

    private func makeContent() -> UIView {
        let parts = [
            makeIcon(),
            makeLabel(text: entry.flow.title, font: Typography.uiDisplay, color: Palette.text),
            makeLabel(text: entry.flow.summary, font: Typography.uiBody, color: Palette.textSecondary),
            makeLabel(text: entry.placeholderNote, font: Typography.uiFootnote, color: Palette.textTertiary),
            makeLabel(text: entry.placeholderLine, font: Typography.uiCode, color: Palette.textSecondary),
        ]
        let stack = UIStackView(arrangedSubviews: parts)
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = Spacing.large
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }

    private func makeIcon() -> UIView {
        let image = UIImage(systemName: entry.flow.symbolName)
        let imageView = UIImageView(image: image)
        imageView.tintColor = entry.kind.tint.uiColor
        imageView.backgroundColor = entry.kind.subtleTint.uiColor
        imageView.contentMode = .center
        imageView.layer.cornerRadius = Radius.field
        imageView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(textStyle: .title3)
        imageView.isAccessibilityElement = false
        let constraints = [
            imageView.widthAnchor.constraint(equalToConstant: Size.placeholderIcon),
            imageView.heightAnchor.constraint(equalToConstant: Size.placeholderIcon),
        ]
        NSLayoutConstraint.activate(constraints)
        return imageView
    }

    private func makeLabel(
        text: String,
        font: UIFont,
        color: ColorToken
    ) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = font
        label.textColor = color.uiColor
        label.numberOfLines = 0
        label.textAlignment = .center
        label.adjustsFontForContentSizeCategory = true
        return label
    }

    private func center(
        _ content: UIView,
        in container: UIView
    ) {
        let guide = container.safeAreaLayoutGuide
        let constraints = [
            content.centerYAnchor.constraint(equalTo: guide.centerYAnchor),
            content.leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: Spacing.huge),
            content.trailingAnchor.constraint(equalTo: guide.trailingAnchor, constant: -Spacing.huge),
        ]
        NSLayoutConstraint.activate(constraints)
    }
}

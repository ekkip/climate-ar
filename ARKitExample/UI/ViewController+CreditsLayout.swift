/*
See LICENSE folder for this sample's licensing information.

Abstract:
Programmatic credits overlay for ViewController.
*/

import UIKit

extension ViewController {

	func buildCreditsPanel() {
		creditsPanel = UIView()
		creditsPanel.translatesAutoresizingMaskIntoConstraints = false
		creditsPanel.backgroundColor = .clear
		creditsPanel.insetsLayoutMarginsFromSafeArea = false

		let gradient = UIImageView(image: UIImage(named: "Gradient07966"))
		gradient.contentMode = .scaleToFill
		gradient.translatesAutoresizingMaskIntoConstraints = false
		creditsPanel.addSubview(gradient)

		let titleLabel = UILabel()
		titleLabel.text = "CREDITS"
		titleLabel.font = UIFont.rubik(.light, size: 29)
		titleLabel.textColor = .white
		titleLabel.translatesAutoresizingMaskIntoConstraints = false
		creditsPanel.addSubview(titleLabel)

		let textContainer = UIView()
		textContainer.backgroundColor = .clear
		textContainer.translatesAutoresizingMaskIntoConstraints = false
		creditsPanel.addSubview(textContainer)

		creditsTextView = UITextView()
		creditsTextView.backgroundColor = .clear
		creditsTextView.textColor = .white
		creditsTextView.font = UIFont.rubik(.light, size: 15)
		creditsTextView.isEditable = false
		creditsTextView.showsHorizontalScrollIndicator = false
		creditsTextView.showsVerticalScrollIndicator = false
		creditsTextView.indicatorStyle = .white
		creditsTextView.dataDetectorTypes = [.link]
		creditsTextView.translatesAutoresizingMaskIntoConstraints = false
		textContainer.addSubview(creditsTextView)

		let closeButton = UIButton(type: .system)
		closeButton.setTitle("×", for: .normal)
		closeButton.setTitleColor(.white, for: .normal)
		closeButton.titleLabel?.font = UIFont.systemFont(ofSize: 54, weight: .thin)
		closeButton.contentEdgeInsets = UIEdgeInsets(top: 1, left: 0, bottom: 12, right: 0)
		closeButton.translatesAutoresizingMaskIntoConstraints = false
		closeButton.addTarget(self, action: #selector(dismissOverlay(_:)), for: .touchUpInside)
		creditsPanel.addSubview(closeButton)

		let logos = UIImageView(image: UIImage(named: "Logos"))
		logos.contentMode = .scaleToFill
		logos.translatesAutoresizingMaskIntoConstraints = false
		creditsPanel.addSubview(logos)

		NSLayoutConstraint.activate([
			gradient.topAnchor.constraint(equalTo: creditsPanel.topAnchor),
			gradient.leadingAnchor.constraint(equalTo: creditsPanel.leadingAnchor),
			gradient.trailingAnchor.constraint(equalTo: creditsPanel.trailingAnchor),
			gradient.bottomAnchor.constraint(equalTo: creditsPanel.bottomAnchor),

			titleLabel.topAnchor.constraint(equalTo: creditsPanel.topAnchor, constant: 21),
			titleLabel.leadingAnchor.constraint(equalTo: creditsPanel.leadingAnchor, constant: 27),

			closeButton.topAnchor.constraint(equalTo: creditsPanel.topAnchor, constant: 20),
			closeButton.trailingAnchor.constraint(equalTo: creditsPanel.trailingAnchor, constant: -20),
			closeButton.widthAnchor.constraint(equalToConstant: 40),
			closeButton.heightAnchor.constraint(equalToConstant: 40),

			textContainer.topAnchor.constraint(equalTo: creditsPanel.topAnchor, constant: 74),
			textContainer.leadingAnchor.constraint(equalTo: creditsPanel.leadingAnchor, constant: 25),
			textContainer.trailingAnchor.constraint(equalTo: creditsPanel.trailingAnchor, constant: -30),
			textContainer.heightAnchor.constraint(equalToConstant: 318),

			creditsTextView.topAnchor.constraint(equalTo: textContainer.topAnchor),
			creditsTextView.leadingAnchor.constraint(equalTo: textContainer.leadingAnchor),
			creditsTextView.trailingAnchor.constraint(equalTo: textContainer.trailingAnchor),
			creditsTextView.bottomAnchor.constraint(equalTo: textContainer.bottomAnchor),

			logos.centerXAnchor.constraint(equalTo: creditsPanel.centerXAnchor),
			logos.bottomAnchor.constraint(equalTo: creditsPanel.bottomAnchor, constant: -30),
			logos.widthAnchor.constraint(equalToConstant: 214),
			logos.heightAnchor.constraint(equalToConstant: 50),
		])
	}

	func installCreditsPanelConstraintsIfNeeded() {
		guard creditsPanelCenterYConstraint == nil else { return }

		let panelSize = StyleParams.overlayPanelSize
		let aspect = panelSize.height / panelSize.width

		let centerY = creditsPanel.centerYAnchor.constraint(
			equalTo: view.centerYAnchor,
			constant: creditsPanelHiddenCenterYOffset
		)
		creditsPanelCenterYConstraint = centerY

		let widthFill = creditsPanel.widthAnchor.constraint(equalTo: view.widthAnchor, constant: -40)
		widthFill.priority = UILayoutPriority(999)

		let heightAspect = creditsPanel.heightAnchor.constraint(
			equalTo: creditsPanel.widthAnchor,
			multiplier: aspect
		)
		heightAspect.priority = UILayoutPriority(999)

		NSLayoutConstraint.activate([
			creditsPanel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
			centerY,
			creditsPanel.widthAnchor.constraint(lessThanOrEqualToConstant: panelSize.width),
			widthFill,
			heightAspect,
			creditsPanel.heightAnchor.constraint(lessThanOrEqualToConstant: panelSize.height),
			creditsPanel.heightAnchor.constraint(lessThanOrEqualTo: view.heightAnchor, constant: -10),
		])
	}
}

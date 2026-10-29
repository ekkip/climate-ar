/*
See LICENSE folder for this sample's licensing information.

Abstract:
Programmatic menu overlay view hierarchy for ViewController.
*/

import UIKit

extension ViewController {

	func buildMenuView() {
		menuView = UIView()
		menuView.translatesAutoresizingMaskIntoConstraints = false
		menuView.backgroundColor = .clear

		menuPanel = UIView()
		menuPanel.translatesAutoresizingMaskIntoConstraints = false
		menuView.addSubview(menuPanel)

		let gradient = UIImageView(image: UIImage(named: "Gradient07966"))
		gradient.contentMode = .scaleToFill
		gradient.translatesAutoresizingMaskIntoConstraints = false
		menuPanel.addSubview(gradient)

		let header = UIView()
		header.backgroundColor = UIColor(white: 0, alpha: 0.25)
		header.translatesAutoresizingMaskIntoConstraints = false
		menuPanel.addSubview(header)

		menuFirstRowButton = menuRowButton(title: "Introduction", action: #selector(menuButtonIntroPressed(_:)))
		let creditsButton = menuRowButton(title: "Credits", action: #selector(menuButtonCreditsPressed(_:)))
		let divider = UIView()
		divider.backgroundColor = UIColor(white: 0, alpha: 0.25)
		divider.translatesAutoresizingMaskIntoConstraints = false

		let settingsBlock = UIView()
		settingsBlock.backgroundColor = UIColor(white: 0, alpha: 0.25)
		settingsBlock.translatesAutoresizingMaskIntoConstraints = false
		menuPanel.addSubview(settingsBlock)

		let localDataLabel = UILabel()
		localDataLabel.text = "Display local data"
		localDataLabel.font = UIFont.rubik(.light, size: 20)
		localDataLabel.textColor = .white
		localDataLabel.translatesAutoresizingMaskIntoConstraints = false

		let restartLabel = UILabel()
		restartLabel.text = "Restart AR experience"
		restartLabel.font = UIFont.rubik(.light, size: 20)
		restartLabel.textColor = .white
		restartLabel.translatesAutoresizingMaskIntoConstraints = false

		menuSwitchDisplayLocalData = UISwitch()
		menuSwitchDisplayLocalData.isOn = true
		menuSwitchDisplayLocalData.tintColor = UIColor(red: 0.2, green: 0.396, blue: 0.439, alpha: 1)
		menuSwitchDisplayLocalData.onTintColor = menuSwitchDisplayLocalData.tintColor
		menuSwitchDisplayLocalData.thumbTintColor = .white
		menuSwitchDisplayLocalData.translatesAutoresizingMaskIntoConstraints = false
		menuSwitchDisplayLocalData.addTarget(self, action: #selector(menuSwitchDisplayLocalDataValueChanged(_:)), for: .valueChanged)

		restartExperienceButton = UIButton(type: .custom)
		let restartSymbol = UIImage(
			systemName: "arrow.counterclockwise",
			withConfiguration: UIImage.SymbolConfiguration(pointSize: 17, weight: .medium)
		)
		restartExperienceButton.setImage(restartSymbol, for: .normal)
		restartExperienceButton.tintColor = .white
		restartExperienceButton.backgroundColor = UIColor(red: 0.2, green: 0.396, blue: 0.439, alpha: 1)
		restartExperienceButton.layer.cornerRadius = 16
		restartExperienceButton.layer.masksToBounds = true
		restartExperienceButton.translatesAutoresizingMaskIntoConstraints = false
		restartExperienceButton.addTarget(self, action: #selector(menuButtonRestartExperiencePressed(_:)), for: .touchUpInside)

		settingsBlock.addSubview(localDataLabel)
		settingsBlock.addSubview(restartLabel)
		settingsBlock.addSubview(menuSwitchDisplayLocalData)
		settingsBlock.addSubview(restartExperienceButton)

		menuPanel.addSubview(menuFirstRowButton)
		menuPanel.addSubview(divider)
		menuPanel.addSubview(creditsButton)

		NSLayoutConstraint.activate([
			menuPanel.topAnchor.constraint(equalTo: menuView.topAnchor),
			menuPanel.leadingAnchor.constraint(equalTo: menuView.leadingAnchor),
			menuPanel.trailingAnchor.constraint(equalTo: menuView.trailingAnchor),
			menuPanel.bottomAnchor.constraint(equalTo: menuView.bottomAnchor),

			gradient.topAnchor.constraint(equalTo: menuPanel.topAnchor),
			gradient.leadingAnchor.constraint(equalTo: menuPanel.leadingAnchor),
			gradient.trailingAnchor.constraint(equalTo: menuPanel.trailingAnchor),
			gradient.bottomAnchor.constraint(equalTo: menuPanel.bottomAnchor),

			header.topAnchor.constraint(equalTo: menuPanel.topAnchor),
			header.leadingAnchor.constraint(equalTo: menuPanel.leadingAnchor),
			header.trailingAnchor.constraint(equalTo: menuPanel.trailingAnchor),
			header.bottomAnchor.constraint(equalTo: menuFirstRowButton.topAnchor),

			menuFirstRowButton.leadingAnchor.constraint(equalTo: menuPanel.leadingAnchor),
			menuFirstRowButton.trailingAnchor.constraint(equalTo: menuPanel.trailingAnchor),
			menuFirstRowButton.heightAnchor.constraint(equalToConstant: 54),

			divider.topAnchor.constraint(equalTo: menuFirstRowButton.bottomAnchor),
			divider.leadingAnchor.constraint(equalTo: menuPanel.leadingAnchor),
			divider.trailingAnchor.constraint(equalTo: menuPanel.trailingAnchor),
			divider.heightAnchor.constraint(equalToConstant: 2),

			creditsButton.topAnchor.constraint(equalTo: divider.bottomAnchor),
			creditsButton.leadingAnchor.constraint(equalTo: menuPanel.leadingAnchor),
			creditsButton.trailingAnchor.constraint(equalTo: menuPanel.trailingAnchor),
			creditsButton.heightAnchor.constraint(equalToConstant: 54),

			settingsBlock.topAnchor.constraint(equalTo: creditsButton.bottomAnchor),
			settingsBlock.leadingAnchor.constraint(equalTo: menuPanel.leadingAnchor),
			settingsBlock.trailingAnchor.constraint(equalTo: menuPanel.trailingAnchor),
			settingsBlock.bottomAnchor.constraint(equalTo: menuPanel.bottomAnchor),
			settingsBlock.heightAnchor.constraint(equalToConstant: 107),

			localDataLabel.leadingAnchor.constraint(
				equalTo: settingsBlock.leadingAnchor,
				constant: StyleParams.menuMarginHorizontal
			),
			localDataLabel.topAnchor.constraint(equalTo: settingsBlock.topAnchor, constant: 8),
			localDataLabel.heightAnchor.constraint(equalToConstant: 40),

			restartLabel.leadingAnchor.constraint(
				equalTo: settingsBlock.leadingAnchor,
				constant: StyleParams.menuMarginHorizontal
			),
			restartLabel.topAnchor.constraint(equalTo: localDataLabel.bottomAnchor, constant: 10),
			restartLabel.heightAnchor.constraint(equalToConstant: 40),

			menuSwitchDisplayLocalData.leadingAnchor.constraint(equalTo: localDataLabel.trailingAnchor, constant: 18),
			menuSwitchDisplayLocalData.topAnchor.constraint(equalTo: settingsBlock.topAnchor, constant: 13),
			menuSwitchDisplayLocalData.trailingAnchor.constraint(
				equalTo: settingsBlock.trailingAnchor,
				constant: -StyleParams.menuMarginHorizontal
			),

			restartExperienceButton.leadingAnchor.constraint(equalTo: restartLabel.trailingAnchor, constant: 18),
			restartExperienceButton.topAnchor.constraint(equalTo: menuSwitchDisplayLocalData.bottomAnchor, constant: 18),
			restartExperienceButton.trailingAnchor.constraint(
				equalTo: settingsBlock.trailingAnchor,
				constant: -StyleParams.menuMarginHorizontal
			),
			restartExperienceButton.widthAnchor.constraint(equalToConstant: 51),
			restartExperienceButton.heightAnchor.constraint(equalToConstant: 32),
		])

		let swipeUp = UISwipeGestureRecognizer(target: self, action: #selector(dismissOverlay(_:)))
		swipeUp.direction = .up
		menuView.addGestureRecognizer(swipeUp)
	}

	func installMenuViewConstraintsIfNeeded() {
		guard !isMenuViewConstraintsInstalled else { return }
		isMenuViewConstraintsInstalled = true

		view.insertSubview(menuView, belowSubview: visibleMenuButton)

		menuHiddenBottomConstraint = menuView.bottomAnchor.constraint(equalTo: view.topAnchor)
		menuExposedTopConstraint = menuView.topAnchor.constraint(equalTo: view.topAnchor)
		menuExposedFirstRowTopConstraint = menuFirstRowButton.topAnchor.constraint(equalTo: visibleMenuButton.bottomAnchor, constant: 10)
		menuExposedTopConstraint.isActive = false
		menuExposedFirstRowTopConstraint.isActive = false

		NSLayoutConstraint.activate([
			menuView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
			menuView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
			menuHiddenBottomConstraint,
		])
	}

	func setMenuExposed(_ exposed: Bool, animated: Bool) {
		installMenuViewConstraintsIfNeeded()

		menuHiddenBottomConstraint.isActive = !exposed
		menuExposedTopConstraint.isActive = exposed
		menuExposedFirstRowTopConstraint.isActive = exposed

		let updateLayout = {
			self.menuPanel.alpha = exposed ? 1 : 0
			self.view.layoutIfNeeded()
		}

		if animated {
			UIView.animate(withDuration: 0.5, animations: updateLayout)
		} else {
			updateLayout()
		}
	}

	private func menuRowButton(title: String, action: Selector) -> UIButton {
		let button = UIButton(type: .system)
		button.setTitle(title, for: .normal)
		button.setTitleColor(.white, for: .normal)
		button.titleLabel?.font = UIFont.rubik(.regular, size: 20)
		button.contentHorizontalAlignment = .left
		let horizontalInset = StyleParams.menuMarginHorizontal
		button.contentEdgeInsets = UIEdgeInsets(top: 0, left: horizontalInset, bottom: 0, right: horizontalInset)
		button.translatesAutoresizingMaskIntoConstraints = false
		button.addTarget(self, action: action, for: .touchUpInside)
		return button
	}
}

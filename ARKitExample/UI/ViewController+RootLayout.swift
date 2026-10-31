/*
See LICENSE folder for this sample's licensing information.

Abstract:
Programmatic root view hierarchy for ViewController (from Main.storyboard).
*/

import ARKit
import UIKit

extension ViewController {
	
	func buildRootLayout() {
		view.backgroundColor = .white
		view.insetsLayoutMarginsFromSafeArea = false
		
		sceneView = ARSCNView()
		view.addSubview(sceneView)
		sceneView.translatesAutoresizingMaskIntoConstraints = false
		NSLayoutConstraint.activate([
			sceneView.topAnchor.constraint(equalTo: view.topAnchor, constant: StyleParams.sceneViewEdgeInset),
			sceneView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: StyleParams.sceneViewEdgeInset),
			sceneView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -StyleParams.sceneViewEdgeInset),
			sceneView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -StyleParams.sceneViewEdgeInset),
		])

		// ADDED FOR APP STORE IMAGERY ONLY!
		buildScenePreviewBackground()

		buildMessagePanel()
		buildGlobePlacementHintLabel()
		buildGlobeControlPanel()
		buildThermometerColumn()
		buildOverlayBackground()
		buildMenuChrome()
		buildClimatePolicyPanel()
	}
	
	private func buildScenePreviewBackground() {
		let bgImageView = UIImageView(image: UIImage(named: "iPad 11 Sanssouci ohne UI"))
		bgImageView.translatesAutoresizingMaskIntoConstraints = false
		view.addSubview(bgImageView)
		bgImageView.pinEdges(to: view)
	}
	
	
	private func buildMessagePanel() {
		let blur = UIBlurEffect(style: .light)
		let messageBlur = UIVisualEffectView(effect: blur)
		messageBlur.translatesAutoresizingMaskIntoConstraints = false
		messagePanel = messageBlur
		view.addSubview(messageBlur)

		let vibrancyBlur = UIBlurEffect(style: .extraLight)
		let vibrancy = UIVisualEffectView(effect: UIVibrancyEffect(blurEffect: vibrancyBlur))
		vibrancy.translatesAutoresizingMaskIntoConstraints = false
		messageBlur.contentView.addSubview(vibrancy)
		vibrancy.pinEdges(to: messageBlur.contentView)

		let stack = UIStackView()
		stack.axis = .vertical
		stack.spacing = StyleParams.messageStackSpacing
		stack.translatesAutoresizingMaskIntoConstraints = false

		featurePointCountLabel = makeFootnoteLabel(text: "Point cloud size")
		messageLabel = makeFootnoteLabel(text: "Tracking status")
		messageLabel.numberOfLines = 3
		debugMessageLabel = makeFootnoteLabel(text: "Messages")
		debugMessageLabel.numberOfLines = 3

		stack.addArrangedSubview(featurePointCountLabel)
		stack.addArrangedSubview(messageLabel)
		stack.addArrangedSubview(debugMessageLabel)
		vibrancy.contentView.addSubview(stack)

		NSLayoutConstraint.activate([
			messageBlur.leadingAnchor.constraint(equalTo: sceneView.leadingAnchor, constant: StyleParams.messagePanelLeading),
			messageBlur.topAnchor.constraint(equalTo: view.topAnchor, constant: StyleParams.messagePanelTopFromSafeArea),
			stack.topAnchor.constraint(equalTo: vibrancy.contentView.topAnchor, constant: StyleParams.messageStackPadding),
			stack.leadingAnchor.constraint(equalTo: vibrancy.contentView.leadingAnchor, constant: StyleParams.messageStackPadding),
			stack.trailingAnchor.constraint(equalTo: vibrancy.contentView.trailingAnchor, constant: -StyleParams.messageStackPadding),
			stack.bottomAnchor.constraint(equalTo: vibrancy.contentView.bottomAnchor, constant: -StyleParams.messageStackPadding),
		])
	}

	private func makeFootnoteLabel(text: String) -> UILabel {
		let label = UILabel()
		label.font = UIFont.preferredFont(forTextStyle: .footnote)
		label.text = text
		label.highlightedTextColor = .white
		label.layer.shadowOffset = CGSize(width: 1, height: 1)
		return label
	}

	private func buildGlobePlacementHintLabel() {
		globePlacementHintLabel = UILabel()
		globePlacementHintLabel.text = "Tap globe to place"
		globePlacementHintLabel.font = UIFont.rubik(.regular, size: StyleParams.globePlacementHintFontSize)
		globePlacementHintLabel.textColor = .white
		globePlacementHintLabel.textAlignment = .center
		globePlacementHintLabel.isUserInteractionEnabled = false
		globePlacementHintLabel.isHidden = true
		globePlacementHintLabel.layer.shadowColor = UIColor.black.cgColor
		globePlacementHintLabel.layer.shadowOffset = CGSize(width: 0, height: 1)
		globePlacementHintLabel.layer.shadowRadius = 2
		globePlacementHintLabel.layer.shadowOpacity = 0.45
		globePlacementHintLabel.translatesAutoresizingMaskIntoConstraints = false
		view.addSubview(globePlacementHintLabel)

		NSLayoutConstraint.activate([
			globePlacementHintLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: StyleParams.globeControlHorizontalInset),
			globePlacementHintLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -StyleParams.globeControlHorizontalInset),
			globePlacementHintLabel.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -StyleParams.globePlacementHintBottomInset),
		])
	}

	private func buildGlobeControlPanel() {
		globeControlPanel = populateGlobeControlPanel()
		globeControlPanel.alpha = 0
		globeControlPanel.isUserInteractionEnabled = false
		globeControlPanel.backgroundColor = .clear
		globeControlPanel.translatesAutoresizingMaskIntoConstraints = false
		view.addSubview(globeControlPanel)

		let touchRegion = TimeSliderTouchRegionView()
		touchRegion.backgroundColor = .clear
		touchRegion.alpha = 0
		touchRegion.isUserInteractionEnabled = false
		touchRegion.translatesAutoresizingMaskIntoConstraints = false
		touchRegion.scrollView = timeScrollView
		touchRegion.onScrollOffsetChanged = { [weak self] in
			self?.applyMainTimeScrollOffsetSideEffects(fromUserScroll: true)
		}
		timeSliderTouchRegion = touchRegion

		view.insertSubview(timeSliderTouchRegion, belowSubview: globeControlPanel)

		NSLayoutConstraint.activate([
			globeControlPanel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: StyleParams.globeControlHorizontalInset),
			globeControlPanel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -StyleParams.globeControlHorizontalInset),
			globeControlPanel.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -StyleParams.timeSliderPanelBottomInsetFromView),
			globeControlPanel.heightAnchor.constraint(equalToConstant: StyleParams.timeSliderHeight),

			timeSliderTouchRegion.leadingAnchor.constraint(equalTo: view.leadingAnchor),
			timeSliderTouchRegion.trailingAnchor.constraint(equalTo: view.trailingAnchor),
			timeSliderTouchRegion.topAnchor.constraint(equalTo: globeControlPanel.topAnchor,
			                                           constant: -StyleParams.globeControlPanelVerticalMargin),
			timeSliderTouchRegion.bottomAnchor.constraint(equalTo: globeControlPanel.bottomAnchor,
			                                              constant: StyleParams.globeControlPanelVerticalMargin),
		])
	}

	private func populateGlobeControlPanel() -> UIView {
		let container = UIView()
		container.backgroundColor = .clear
		container.translatesAutoresizingMaskIntoConstraints = false

		let leftBg = UIImageView(image: UIImage(named: "TimeSliderBackgroundLeft"))
		leftBg.alpha = 0.75
		leftBg.contentMode = .scaleToFill
		leftBg.translatesAutoresizingMaskIntoConstraints = false
		container.addSubview(leftBg)

		let focusBg = UIImageView(image: UIImage(named: "TimeSliderBackgroundFocus"))
		focusBg.alpha = 0.75
		focusBg.contentMode = .scaleToFill
		focusBg.translatesAutoresizingMaskIntoConstraints = false
		container.addSubview(focusBg)

		let rightBg = UIImageView(image: UIImage(named: "TimeSliderBackgroundRight"))
		rightBg.alpha = 0.75
		rightBg.contentMode = .scaleToFill
		rightBg.translatesAutoresizingMaskIntoConstraints = false
		container.addSubview(rightBg)

		let focusWrapper = UIView()
		focusWrapper.backgroundColor = .clear
		focusWrapper.translatesAutoresizingMaskIntoConstraints = false
		container.addSubview(focusWrapper)

		let scrollWrapper = UIView()
		scrollWrapper.backgroundColor = .clear
		scrollWrapper.translatesAutoresizingMaskIntoConstraints = false
		container.addSubview(scrollWrapper)

		timeScrollWrapper = scrollWrapper
		focusScrollWrapper = focusWrapper

		timeScrollView = UIScrollView()
		timeScrollView.showsHorizontalScrollIndicator = false
		timeScrollView.showsVerticalScrollIndicator = false
		timeScrollView.backgroundColor = .clear
		timeScrollView.delegate = self
		timeScrollView.translatesAutoresizingMaskIntoConstraints = false
		configureGlobeTimeScrollView(timeScrollView)
		scrollWrapper.addSubview(timeScrollView)
		timeScrollView.pinEdges(to: scrollWrapper)

		focusTimeScrollView = UIScrollView()
		focusTimeScrollView.showsHorizontalScrollIndicator = false
		focusTimeScrollView.showsVerticalScrollIndicator = false
		focusTimeScrollView.backgroundColor = .clear
		focusTimeScrollView.delegate = self
		focusTimeScrollView.translatesAutoresizingMaskIntoConstraints = false
		configureGlobeTimeScrollView(focusTimeScrollView)
		focusWrapper.addSubview(focusTimeScrollView)

		NSLayoutConstraint.activate([
			leftBg.leadingAnchor.constraint(equalTo: container.leadingAnchor),
			leftBg.topAnchor.constraint(equalTo: container.topAnchor),
			leftBg.bottomAnchor.constraint(equalTo: container.bottomAnchor),

			focusBg.leadingAnchor.constraint(equalTo: leftBg.trailingAnchor),
			focusBg.topAnchor.constraint(equalTo: container.topAnchor),
			focusBg.bottomAnchor.constraint(equalTo: container.bottomAnchor),
			focusBg.centerXAnchor.constraint(equalTo: container.centerXAnchor),
			focusBg.widthAnchor.constraint(equalToConstant: StyleParams.timeSliderFocusWidth),

			rightBg.leadingAnchor.constraint(equalTo: focusBg.trailingAnchor),
			rightBg.trailingAnchor.constraint(equalTo: container.trailingAnchor),
			rightBg.topAnchor.constraint(equalTo: container.topAnchor),
			rightBg.bottomAnchor.constraint(equalTo: container.bottomAnchor),
		])
		scrollWrapper.pinEdges(to: container)
		focusWrapper.pinEdges(to: container)
		focusTimeScrollView.pinEdges(to: focusWrapper)

		return container
	}

	private func buildThermometerColumn() {
		thermometerPanel = UIView()
		thermometerPanel.clipsToBounds = true
		thermometerPanel.alpha = 0
		thermometerPanel.tag = 50
		thermometerPanel.isUserInteractionEnabled = false
		thermometerPanel.backgroundColor = .clear
		thermometerPanel.layer.cornerRadius = 6
		thermometerPanel.translatesAutoresizingMaskIntoConstraints = false
		view.addSubview(thermometerPanel)

		NSLayoutConstraint.activate([
			thermometerPanel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: StyleParams.thermometerLeadingFromSafeArea),
			thermometerPanel.widthAnchor.constraint(equalToConstant: StyleParams.thermometerWidth),
			thermometerPanel.heightAnchor.constraint(equalToConstant: StyleParams.thermometerHeight),
			thermometerPanel.bottomAnchor.constraint(equalTo: globeControlPanel.topAnchor, constant: -StyleParams.globeControlPanelVerticalMargin),
		])

		thermometerContainer = UIView()
		thermometerContainer.backgroundColor = UIColor(white: 1, alpha: 0.3)
		thermometerContainer.layer.cornerRadius = 6
		thermometerContainer.translatesAutoresizingMaskIntoConstraints = false
		thermometerPanel.addSubview(thermometerContainer)

		thermometerMercury = UIImageView(image: UIImage(named: "ThermometerMercury"))
		thermometerMercury.clipsToBounds = true
		thermometerMercury.contentMode = .bottom
		thermometerMercury.layer.cornerRadius = 6
		thermometerMercury.frame = CGRect(x: 0, y: 0, width: StyleParams.thermometerWidth, height: StyleParams.thermometerMercuryImageHeight)

		thermometerInnerGlow = UIImageView(image: UIImage(named: "ThermometerInnerGlow"))
		thermometerInnerGlow.layer.cornerRadius = 6
		thermometerInnerGlow.frame = CGRect(x: 0, y: 320, width: StyleParams.thermometerWidth, height: 30)

		thermometerContainer.addSubview(thermometerMercury)
		thermometerContainer.addSubview(thermometerInnerGlow)

		NSLayoutConstraint.activate([
			thermometerContainer.leadingAnchor.constraint(equalTo: thermometerPanel.leadingAnchor),
			thermometerContainer.trailingAnchor.constraint(equalTo: thermometerPanel.trailingAnchor),
			thermometerContainer.bottomAnchor.constraint(equalTo: thermometerPanel.bottomAnchor),
			thermometerContainer.heightAnchor.constraint(equalToConstant: StyleParams.thermometerContainerHeight),
		])

		thermometerThreshold2DegPanel = makeSidePanel(tag: 40, size: StyleParams.threshold2PanelSize)
		thermometerThreshold1DegPanel = makeSidePanel(tag: 30, size: StyleParams.threshold1PanelSize)
		thermometerCO2CounterPanel = makeSidePanel(tag: 20, size: StyleParams.co2PanelSize)

		view.addSubview(thermometerThreshold2DegPanel)
		view.addSubview(thermometerThreshold1DegPanel)
		view.addSubview(thermometerCO2CounterPanel)

		populateThermometerSidePanels()

		NSLayoutConstraint.activate([
			thermometerThreshold2DegPanel.leadingAnchor.constraint(equalTo: thermometerPanel.trailingAnchor, constant: StyleParams.thermometerSidePanelLeadingOffset),
			thermometerThreshold1DegPanel.leadingAnchor.constraint(equalTo: thermometerPanel.trailingAnchor, constant: StyleParams.thermometerSidePanelLeadingOffset),
			thermometerCO2CounterPanel.leadingAnchor.constraint(equalTo: thermometerPanel.trailingAnchor, constant: StyleParams.thermometerSidePanelLeadingOffset),

			thermometerThreshold2DegPanel.topAnchor.constraint(equalTo: thermometerPanel.topAnchor, constant: 324),
			thermometerThreshold1DegPanel.topAnchor.constraint(equalTo: thermometerThreshold2DegPanel.bottomAnchor, constant: StyleParams.thresholdVerticalGap),
			thermometerCO2CounterPanel.topAnchor.constraint(equalTo: thermometerThreshold1DegPanel.bottomAnchor, constant: StyleParams.co2PanelTopGapFromThreshold1),

			thermometerCO2CounterPanel.bottomAnchor.constraint(equalTo: thermometerPanel.bottomAnchor),
		])
	}

	private func makeSidePanel(tag: Int, size: CGSize) -> UIView {
		let panel = UIView()
		panel.tag = tag
		panel.alpha = 0
		panel.isHidden = true
		panel.isUserInteractionEnabled = false
		panel.backgroundColor = .clear
		panel.translatesAutoresizingMaskIntoConstraints = false
		NSLayoutConstraint.activate([
			panel.widthAnchor.constraint(equalToConstant: size.width),
			panel.heightAnchor.constraint(equalToConstant: size.height),
		])
		return panel
	}

	private func populateThermometerSidePanels() {
		let threshold2Label = UILabel()
		threshold2Label.text = "2°C"
		threshold2Label.font = UIFont.rubik(.light, size: 26)
		threshold2Label.textColor = .white
		threshold2Label.frame = CGRect(x: 8, y: 0, width: 46, height: 32)
		thermometerThreshold2DegPanel.addSubview(threshold2Label)

		let threshold2Subtitle = UILabel()
		threshold2Subtitle.text = "THRESHOLD"
		threshold2Subtitle.font = UIFont.rubik(.medium, size: 12)
		threshold2Subtitle.textColor = .white
		threshold2Subtitle.frame = CGRect(x: 8, y: 24, width: 74, height: 24)
		thermometerThreshold2DegPanel.addSubview(threshold2Subtitle)

		let threshold1Label = UILabel()
		threshold1Label.text = "1°C"
		threshold1Label.font = UIFont.rubik(.light, size: 26)
		threshold1Label.textColor = .white
		threshold1Label.frame = CGRect(x: 8, y: 0, width: 46, height: 32)
		thermometerThreshold1DegPanel.addSubview(threshold1Label)

		let co2Title = UILabel()
		co2Title.text = "GLOBAL EMISSIONS"
		co2Title.numberOfLines = 2
		co2Title.font = UIFont.rubik(.regular, size: 12)
		co2Title.textColor = .white
		co2Title.frame = CGRect(x: 8, y: 0, width: 74, height: 34)
		thermometerCO2CounterPanel.addSubview(co2Title)

		thermometerCO2CounterLabel = UILabel()
		thermometerCO2CounterLabel.text = "1000000"
		thermometerCO2CounterLabel.font = UIFont.rubik(.light, size: 20)
		thermometerCO2CounterLabel.textColor = .white
		thermometerCO2CounterLabel.frame = CGRect(x: 8, y: 37, width: 88, height: 25)
		thermometerCO2CounterPanel.addSubview(thermometerCO2CounterLabel)

		let co2Unit = UILabel()
		co2Unit.text = "Mt CO₂"
		co2Unit.font = UIFont.rubik(.medium, size: 15)
		co2Unit.textColor = .white
		co2Unit.frame = CGRect(x: 8, y: 55, width: 74, height: 24)
		thermometerCO2CounterPanel.addSubview(co2Unit)
	}

	private func buildOverlayBackground() {
		overlayBackground = UIButton(type: .custom)
		overlayBackground.alpha = 0
		overlayBackground.backgroundColor = UIColor(white: 0, alpha: 0.67)
		overlayBackground.isUserInteractionEnabled = false
		overlayBackground.translatesAutoresizingMaskIntoConstraints = false
		overlayBackground.addTarget(self, action: #selector(dismissOverlay(_:)), for: .touchUpInside)
		view.addSubview(overlayBackground)
		overlayBackground.pinEdges(to: view)
	}

	private func buildMenuChrome() {
		visibleMenuButton = UIView()
		visibleMenuButton.backgroundColor = .clear
		visibleMenuButton.translatesAutoresizingMaskIntoConstraints = false
		view.addSubview(visibleMenuButton)

		menuButtonBarTop = UIView.barView()
		menuButtonBarCenter0 = UIView.barView()
		menuButtonBarCenter1 = UIView.barView()
		menuButtonBarBottom = UIView.barView()
		[menuButtonBarTop, menuButtonBarCenter0, menuButtonBarCenter1, menuButtonBarBottom].forEach {
			$0.translatesAutoresizingMaskIntoConstraints = true
			visibleMenuButton.addSubview($0)
		}
		layoutMenuButtonBars()

		visibleMenuButtonTopConstraint = visibleMenuButton.topAnchor.constraint(
			equalTo: view.topAnchor,
			constant: StyleParams.visibleMenuButtonTopMargin
		)
		visibleMenuButtonTrailingConstraint = visibleMenuButton.trailingAnchor.constraint(
			equalTo: view.trailingAnchor,
			constant: -StyleParams.safeAreaMarginTrailing
		)

		NSLayoutConstraint.activate([
			visibleMenuButton.widthAnchor.constraint(equalToConstant: StyleParams.visibleMenuButtonSize),
			visibleMenuButton.heightAnchor.constraint(equalToConstant: StyleParams.visibleMenuButtonSize),
			visibleMenuButtonTopConstraint,
			visibleMenuButtonTrailingConstraint,
		])

		menuButton = UIButton(type: .custom)
		menuButton.translatesAutoresizingMaskIntoConstraints = false
		menuButton.addTarget(self, action: #selector(menuButtonPressed(_:)), for: .touchUpInside)
		view.addSubview(menuButton)

		NSLayoutConstraint.activate([
			menuButton.widthAnchor.constraint(equalToConstant: StyleParams.menuButtonSize),
			menuButton.heightAnchor.constraint(equalToConstant: StyleParams.menuButtonSize),
			menuButton.centerXAnchor.constraint(equalTo: visibleMenuButton.centerXAnchor),
			menuButton.centerYAnchor.constraint(equalTo: visibleMenuButton.centerYAnchor),
		])

		view.setNeedsUpdateConstraints()
	}

	func applyMenuChromeOcclusionConstraintsIfNeeded() {
		guard let visibleMenuButtonTopConstraint else { return }

		if #available(iOS 27.1, *) {
			let shouldDisplace = MenuChromeLayout.shouldDisplaceForDynamicIsland(
				bounds: view.bounds,
				horizontalSizeClass: traitCollection.horizontalSizeClass,
				verticalSizeClass: traitCollection.verticalSizeClass
			)
			visibleMenuButtonTopConstraint.constant = MenuChromeLayout.occlusionTopInset(for: view, shouldDisplace: shouldDisplace) ?? StyleParams.visibleMenuButtonTopMargin
		} else {
			visibleMenuButtonTopConstraint.constant = StyleParams.visibleMenuButtonTopMargin
		}
	}

	func layoutMenuButtonBars() {
		menuButtonBarTop.frame = CGRect(x: 0, y: 4, width: 24, height: 2)
		menuButtonBarCenter0.frame = CGRect(x: 0, y: 11, width: 24, height: 2)
		menuButtonBarCenter1.frame = CGRect(x: 0, y: 11, width: 24, height: 2)
		menuButtonBarBottom.frame = CGRect(x: 0, y: 18, width: 24, height: 2)
	}
	
	private func buildClimatePolicyPanel() {
		climatePolicySimulationPanel = UIView()
		climatePolicySimulationPanel.tag = 10
		climatePolicySimulationPanel.alpha = 0
		climatePolicySimulationPanel.isHidden = true
		climatePolicySimulationPanel.backgroundColor = .clear
		climatePolicySimulationPanel.translatesAutoresizingMaskIntoConstraints = false
		view.addSubview(climatePolicySimulationPanel)

		let label = UILabel()
		label.text = "Climate Policy"
		label.numberOfLines = 2
		label.textAlignment = .right
		label.font = UIFont.rubik(.regular, size: 16)
		label.textColor = .white
		label.translatesAutoresizingMaskIntoConstraints = false

		climatePolicySwitch = UISwitch()
		
		climatePolicySwitch.onTintColor = StyleParams.green
		if #available(iOS 26, *) {
			climatePolicySwitch.layer.cornerRadius = climatePolicySwitch.frame.height / 2
//			climatePolicySwitch.backgroundColor = StyleParams.red.withAlphaComponent(0.75)
			climatePolicySwitch.layer.borderWidth = 2.0
			climatePolicySwitch.layer.borderColor = StyleParams.red.cgColor
		} else {
			climatePolicySwitch.tintColor = StyleParams.red
		}
		climatePolicySwitch.thumbTintColor = .white
		climatePolicySwitch.translatesAutoresizingMaskIntoConstraints = false
		climatePolicySwitch.addTarget(self, action: #selector(climatePolicySimulationSwitchValueChanged(_:)), for: .valueChanged)

		climatePolicySimulationPanel.addSubview(label)
		climatePolicySimulationPanel.addSubview(climatePolicySwitch)

		NSLayoutConstraint.activate([
			climatePolicySimulationPanel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -StyleParams.safeAreaMarginTrailing),
			climatePolicySimulationPanel.bottomAnchor.constraint(equalTo: globeControlPanel.topAnchor, constant: -StyleParams.globeControlPanelVerticalMargin),

			label.leadingAnchor.constraint(equalTo: climatePolicySimulationPanel.leadingAnchor),
			label.centerYAnchor.constraint(equalTo: climatePolicySimulationPanel.centerYAnchor),

			climatePolicySwitch.leadingAnchor.constraint(equalTo: label.trailingAnchor, constant: StyleParams.switchLabelMargin),
			climatePolicySwitch.trailingAnchor.constraint(equalTo: climatePolicySimulationPanel.trailingAnchor),
			climatePolicySwitch.topAnchor.constraint(equalTo: climatePolicySimulationPanel.topAnchor),
			climatePolicySwitch.bottomAnchor.constraint(equalTo: climatePolicySimulationPanel.bottomAnchor),
		])
	}
}

/*
See LICENSE folder for this sample's licensing information.

Abstract:
Programmatic introduction overlay for ViewController.
*/

import UIKit

extension ViewController {

	func buildIntroductionPanel() {
		introductionPanel = UIView()
		introductionPanel.translatesAutoresizingMaskIntoConstraints = false
		introductionPanel.backgroundColor = .clear

		let gradient = UIImageView(image: UIImage(named: "Gradient07966"))
		gradient.contentMode = .scaleToFill
		gradient.translatesAutoresizingMaskIntoConstraints = false
		introductionPanel.addSubview(gradient)

		introductionScrollView = UIScrollView()
		introductionScrollView.isPagingEnabled = true
		introductionScrollView.showsHorizontalScrollIndicator = false
		introductionScrollView.showsVerticalScrollIndicator = false
		introductionScrollView.bouncesZoom = false
		introductionScrollView.backgroundColor = .clear
		introductionScrollView.delegate = self
		introductionScrollView.translatesAutoresizingMaskIntoConstraints = false
		introductionPanel.addSubview(introductionScrollView)

		let closeButton = UIButton(type: .system)
		closeButton.setTitle("×", for: .normal)
		closeButton.setTitleColor(.white, for: .normal)
		closeButton.titleLabel?.font = UIFont.systemFont(ofSize: 54, weight: .thin)
		closeButton.contentEdgeInsets = UIEdgeInsets(top: 1, left: 0, bottom: 12, right: 0)
		closeButton.translatesAutoresizingMaskIntoConstraints = false
		closeButton.addTarget(self, action: #selector(dismissOverlay(_:)), for: .touchUpInside)
		introductionPanel.addSubview(closeButton)

		introductionPageControl = UIPageControl()
		introductionPageControl.numberOfPages = 3
		introductionPageControl.translatesAutoresizingMaskIntoConstraints = false
		introductionPanel.addSubview(introductionPageControl)

		NSLayoutConstraint.activate([
			gradient.topAnchor.constraint(equalTo: introductionPanel.topAnchor),
			gradient.leadingAnchor.constraint(equalTo: introductionPanel.leadingAnchor),
			gradient.trailingAnchor.constraint(equalTo: introductionPanel.trailingAnchor),
			gradient.bottomAnchor.constraint(equalTo: introductionPanel.bottomAnchor),

			introductionScrollView.topAnchor.constraint(equalTo: introductionPanel.topAnchor),
			introductionScrollView.leadingAnchor.constraint(equalTo: introductionPanel.leadingAnchor),
			introductionScrollView.trailingAnchor.constraint(equalTo: introductionPanel.trailingAnchor),
			introductionScrollView.bottomAnchor.constraint(equalTo: introductionPanel.bottomAnchor),

			closeButton.topAnchor.constraint(equalTo: introductionPanel.topAnchor, constant: 20),
			closeButton.trailingAnchor.constraint(equalTo: introductionPanel.trailingAnchor, constant: -20),
			closeButton.widthAnchor.constraint(equalToConstant: 40),
			closeButton.heightAnchor.constraint(equalToConstant: 40),

			introductionPageControl.centerXAnchor.constraint(equalTo: introductionPanel.centerXAnchor),
			introductionPageControl.bottomAnchor.constraint(equalTo: introductionPanel.bottomAnchor, constant: -23),
		])

		let page1Text = """
When burning coal, oil and gas, carbon dioxide—also known as CO₂—is released into the atmosphere.

To date, CO₂ emissions have risen dramatically. In the short industrial history of just 250 years, humans have increased the amount of CO₂
in the atmosphere by around 40 %.
An alarming value unprecedented on Earth in the past four million years.
"""
		let page2Text = """
Humankind has accumulated CO₂ and other greenhouse gases in the atmos-
phere which has already increased average global temperature by one degree Celsius since 1750.

In order to stop global warming, humankind needs to stop emitting CO₂ and reduce other greenhouse gas emissions. The earlier we stop, the less harmful the effects of global warming will be.
"""
		let pages: [(title: String, body: String)] = [
			("INTRODUCTION", page1Text),
			("GLOBAL WARMING", page2Text),
			("GET READY", "Explore the history—and possible futures—of CO₂ emissions in augmented reality!"),
		]

		var previousPage: UIView?
		for (index, pageContent) in pages.enumerated() {
			let page = makeIntroductionPage(title: pageContent.title, body: pageContent.body, isLastPage: index == 2)
			introductionScrollView.addSubview(page)
			page.translatesAutoresizingMaskIntoConstraints = false

			let frameGuide = introductionScrollView.frameLayoutGuide
			let contentGuide = introductionScrollView.contentLayoutGuide

			NSLayoutConstraint.activate([
				page.topAnchor.constraint(equalTo: contentGuide.topAnchor),
				page.bottomAnchor.constraint(equalTo: contentGuide.bottomAnchor),
				page.widthAnchor.constraint(equalTo: frameGuide.widthAnchor),
				page.heightAnchor.constraint(equalTo: frameGuide.heightAnchor),
			])
			if let previousPage {
				page.leadingAnchor.constraint(equalTo: previousPage.trailingAnchor).isActive = true
			} else {
				page.leadingAnchor.constraint(equalTo: contentGuide.leadingAnchor).isActive = true
			}
			if index == pages.count - 1 {
				page.trailingAnchor.constraint(equalTo: contentGuide.trailingAnchor).isActive = true
			}
			previousPage = page
		}

		introductionPanel.layoutIfNeeded()
		updateIntroductionScrollLayout()
	}

	private func makeIntroductionPage(title: String, body: String, isLastPage: Bool) -> UIView {
		let page = UIView()
		page.backgroundColor = .clear

		let titleLabel = UILabel()
		titleLabel.text = title
		titleLabel.font = UIFont.rubik(.light, size: 29)
		titleLabel.textColor = .white
		titleLabel.translatesAutoresizingMaskIntoConstraints = false
		page.addSubview(titleLabel)

		let bodyView = UITextView()
		bodyView.backgroundColor = .clear
		bodyView.textColor = .white
		bodyView.font = UIFont.rubik(.regular, size: 15)
		bodyView.text = body
		bodyView.isEditable = false
		bodyView.isScrollEnabled = true
		bodyView.textContainerInset = .zero
		bodyView.textContainer.lineFragmentPadding = 0
		bodyView.translatesAutoresizingMaskIntoConstraints = false
		page.addSubview(bodyView)

		let bodyHeight: CGFloat = isLastPage ? 80 : 267

		NSLayoutConstraint.activate([
			titleLabel.topAnchor.constraint(equalTo: page.topAnchor, constant: 100),
			titleLabel.leadingAnchor.constraint(equalTo: page.leadingAnchor, constant: 27),
			titleLabel.trailingAnchor.constraint(equalTo: page.trailingAnchor, constant: -31),

			bodyView.topAnchor.constraint(equalTo: page.topAnchor, constant: 160),
			bodyView.leadingAnchor.constraint(equalTo: page.leadingAnchor, constant: 24),
			bodyView.trailingAnchor.constraint(equalTo: page.trailingAnchor, constant: -31),
			bodyView.heightAnchor.constraint(equalToConstant: bodyHeight),
		])

		if isLastPage {

			let startButton = UIButton(type: .system)
			startButton.setTitle("Start", for: .normal)
			startButton.setTitleColor(.white, for: .normal)
			startButton.titleLabel?.font = UIFont.rubik(.light, size: 29)
			startButton.backgroundColor = UIColor(red: 0.157, green: 0.188, blue: 0.239, alpha: 1)
			startButton.translatesAutoresizingMaskIntoConstraints = false
			startButton.addTarget(self, action: #selector(dismissOverlay(_:)), for: .touchUpInside)
			page.addSubview(startButton)

			showIntroductionOnStartupButton = UIButton()
			showIntroductionOnStartupButton.titleLabel?.font = .systemFont(ofSize: 28)
			showIntroductionOnStartupButton.setTitle("◉", for: .normal)
			showIntroductionOnStartupButton.setTitleColor(.white, for: .normal)
			showIntroductionOnStartupButton.contentEdgeInsets = UIEdgeInsets(top: 0, left: 8, bottom: 0, right: 0)
			showIntroductionOnStartupButton.translatesAutoresizingMaskIntoConstraints = false
			showIntroductionOnStartupButton.addTarget(self, action: #selector(showIntroductionOnStartupButtonPressed(_:)), for: .touchUpInside)
			page.addSubview(showIntroductionOnStartupButton)

			let startupHint = UITextView()
			startupHint.backgroundColor = .clear
			startupHint.textColor = .white
			startupHint.font = UIFont.rubik(.regular, size: 11)
			startupHint.text = "Show introduction every time I open the app"
			startupHint.isEditable = false
			startupHint.isScrollEnabled = false
			startupHint.isUserInteractionEnabled = false
			startupHint.translatesAutoresizingMaskIntoConstraints = false
			page.addSubview(startupHint)

			NSLayoutConstraint.activate([
				startButton.topAnchor.constraint(equalTo: page.topAnchor, constant: 293),
				startButton.leadingAnchor.constraint(equalTo: page.leadingAnchor, constant: 27),
				startButton.trailingAnchor.constraint(equalTo: page.trailingAnchor, constant: -31),
				startButton.heightAnchor.constraint(equalToConstant: 55),

				showIntroductionOnStartupButton.topAnchor.constraint(equalTo: page.topAnchor, constant: 367),
				showIntroductionOnStartupButton.leadingAnchor.constraint(equalTo: page.leadingAnchor, constant: 12),
				showIntroductionOnStartupButton.widthAnchor.constraint(equalToConstant: 45),
				showIntroductionOnStartupButton.heightAnchor.constraint(equalToConstant: 45),

				startupHint.leadingAnchor.constraint(equalTo: showIntroductionOnStartupButton.trailingAnchor),
				startupHint.trailingAnchor.constraint(equalTo: page.trailingAnchor, constant: -20),
				startupHint.centerYAnchor.constraint(equalTo: showIntroductionOnStartupButton.centerYAnchor),
			])
		}

		return page
	}

	func installIntroductionPanelConstraintsIfNeeded() {
		guard introductionPanelCenterYConstraint == nil else { return }

		let panelSize = StyleParams.overlayPanelSize
		let aspect = panelSize.height / panelSize.width

		let centerY = introductionPanel.centerYAnchor.constraint(
			equalTo: view.centerYAnchor,
			constant: introductionPanelHiddenCenterYOffset
		)
		introductionPanelCenterYConstraint = centerY

		let widthFill = introductionPanel.widthAnchor.constraint(equalTo: view.widthAnchor, constant: -40)
		widthFill.priority = UILayoutPriority(999)

		let heightAspect = introductionPanel.heightAnchor.constraint(
			equalTo: introductionPanel.widthAnchor,
			multiplier: aspect
		)
		heightAspect.priority = UILayoutPriority(999)

		NSLayoutConstraint.activate([
			introductionPanel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
			centerY,
			introductionPanel.widthAnchor.constraint(lessThanOrEqualToConstant: panelSize.width),
			widthFill,
			heightAspect,
			introductionPanel.heightAnchor.constraint(lessThanOrEqualToConstant: panelSize.height),
			introductionPanel.heightAnchor.constraint(lessThanOrEqualTo: view.heightAnchor, constant: -10),
		])
	}

	func updateIntroductionScrollLayout() {
		guard introductionScrollView != nil else { return }

		introductionPanel.superview?.layoutIfNeeded()

		let pageWidth = introductionScrollView.bounds.width
		guard pageWidth > 0 else { return }

		if lastIntroductionPageWidth > 0, abs(pageWidth - lastIntroductionPageWidth) > 0.5 {
			let previousPageIndex = min(
				max(0, Int(round(introductionScrollView.contentOffset.x / lastIntroductionPageWidth))),
				2
			)
			introductionScrollView.setContentOffset(
				CGPoint(x: pageWidth * CGFloat(previousPageIndex), y: 0),
				animated: false
			)
		}
		lastIntroductionPageWidth = pageWidth

		introductionPageControl.numberOfPages = 3
		let pageIndex = min(
			max(0, Int(round(introductionScrollView.contentOffset.x / pageWidth))),
			introductionPageControl.numberOfPages - 1
		)
		introductionPageControl.goTo(pageIndex)
	}
}

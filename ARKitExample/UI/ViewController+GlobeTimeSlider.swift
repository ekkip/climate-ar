/*
See LICENSE folder for this sample's licensing information.

Abstract:
Time slider label layout and gradient masks that track Auto Layout bounds.
*/

import UIKit

private enum GlobeTimeSliderMetrics {
	static let yearLabelCount = 36
	static let yearLabelWidth: CGFloat = 80
	static let yearLabelY: CGFloat = 4
	static let yearLabelHeight: CGFloat = 28
	static let centerOffset: CGFloat = 40
	static let yearIndexMax = 349
	static let yearLabelTagBase = 1_000

	static func contentWidth(forViewportWidth viewportWidth: CGFloat) -> CGFloat {
		let padding = viewportWidth / 2 - centerOffset
		return padding + CGFloat(yearLabelCount) * yearLabelWidth + padding
	}

	static func maxContentOffsetX(forViewportWidth viewportWidth: CGFloat) -> CGFloat {
		let contentWidth = contentWidth(forViewportWidth: viewportWidth)
		return max(0, contentWidth - viewportWidth)
	}

	static func pixelAligned(_ value: CGFloat, scale: CGFloat) -> CGFloat {
		guard scale > 0 else { return value }
		return (value * scale).rounded() / scale
	}
}

extension ViewController {

	func configureGlobeTimeScrollView(_ scrollView: UIScrollView) {
		scrollView.contentInset = .zero
		scrollView.scrollIndicatorInsets = .zero
		scrollView.contentInsetAdjustmentBehavior = .never
		if #available(iOS 13.0, *) {
			scrollView.automaticallyAdjustsScrollIndicatorInsets = false
		}
	}

	func applyMainTimeScrollOffsetSideEffects(fromUserScroll: Bool) {
		focusTimeScrollView.contentOffset = timeScrollView.contentOffset

		let scrollRange = mainTimeScrollContentOffsetRange()
		let normalizedOffsetX = mainTimeScrollNormalizedContentOffsetX()
		let yearPosition = scrollRange > 0
			? Double(350 * normalizedOffsetX / scrollRange)
			: 0
		currentYear = min(max(0, Int(yearPosition.rounded())), 349)

		setThermometer()
		setPanelVisibilities()
		if fromUserScroll, globe.canUpdateYearWhileScrolling {
			globe.scrubYear(to: yearPosition)
		}
	}

	func installGlobeTimeSliderContentIfNeeded() {
		guard !globeTimeSliderContentInstalled else { return }
		globeTimeSliderContentInstalled = true

		focusScrollWrapper.isUserInteractionEnabled = false
		focusTimeScrollView.isUserInteractionEnabled = false

		for index in 0..<GlobeTimeSliderMetrics.yearLabelCount {
			let yearLabel = UILabel(frame: .zero)
			yearLabel.tag = GlobeTimeSliderMetrics.yearLabelTagBase + index
			yearLabel.text = "\((175 + index) * 10)"
			yearLabel.font = UIFont.rubik(.light, size: 26)
			yearLabel.textColor = .white
			yearLabel.textAlignment = .center
			timeScrollView.addSubview(yearLabel)

			let focusYearLabel = yearLabel.clone()
			focusYearLabel.tag = yearLabel.tag
			focusYearLabel.textColor = .black
			focusTimeScrollView.addSubview(focusYearLabel)
		}

		installGlobeTimeSliderMaskLayersIfNeeded()
	}

	func updateGlobeTimeSliderLayout(preserveYear: Bool) {
		guard globeTimeSliderContentInstalled else { return }
		guard timeScrollView.bounds.width > 0 else { return }

		configureGlobeTimeScrollView(timeScrollView)
		configureGlobeTimeScrollView(focusTimeScrollView)

		let yearToPreserve = preserveYear ? currentYear : 0
		let width = timeScrollView.bounds.width
		let widthChanged = abs(width - lastGlobeTimeSliderLayoutWidth) > 0.5

		if widthChanged {
			lastGlobeTimeSliderLayoutWidth = width
			let scale = timeScrollView.traitCollection.displayScale
			let padding = GlobeTimeSliderMetrics.pixelAligned(
				width / 2 - GlobeTimeSliderMetrics.centerOffset,
				scale: scale
			)

			for index in 0..<GlobeTimeSliderMetrics.yearLabelCount {
				let frame = CGRect(
					x: padding + CGFloat(index) * GlobeTimeSliderMetrics.yearLabelWidth,
					y: GlobeTimeSliderMetrics.yearLabelY,
					width: GlobeTimeSliderMetrics.yearLabelWidth,
					height: GlobeTimeSliderMetrics.yearLabelHeight
				)

				if let mainLabel = timeScrollView.viewWithTag(GlobeTimeSliderMetrics.yearLabelTagBase + index) {
					mainLabel.frame = frame
				}
				if let focusLabel = focusTimeScrollView.viewWithTag(GlobeTimeSliderMetrics.yearLabelTagBase + index) {
					focusLabel.frame = frame
				}
			}

			let contentWidth = GlobeTimeSliderMetrics.pixelAligned(
				padding + CGFloat(GlobeTimeSliderMetrics.yearLabelCount) * GlobeTimeSliderMetrics.yearLabelWidth + padding,
				scale: scale
			)
			let contentSize = CGSize(width: contentWidth, height: GlobeTimeSliderMetrics.yearLabelHeight + GlobeTimeSliderMetrics.yearLabelY)
			timeScrollView.contentSize = contentSize
			focusTimeScrollView.contentSize = contentSize
		}

		updateGlobeTimeSliderMaskLayers()

		if widthChanged || !preserveYear {
			let offsetX = contentOffsetX(forYearIndex: yearToPreserve)
			timeScrollView.setContentOffset(CGPoint(x: offsetX, y: 0), animated: false)
			focusTimeScrollView.contentOffset = timeScrollView.contentOffset
		}

		if !preserveYear {
			currentYear = 0
		}
	}

	private func installGlobeTimeSliderMaskLayersIfNeeded() {
		guard timeScrollGradientMask == nil else { return }

		let gradientMask = CAGradientLayer()
		gradientMask.startPoint = CGPoint(x: 0, y: 0.5)
		gradientMask.endPoint = CGPoint(x: 1, y: 0.5)
		gradientMask.colors = [
			UIColor.clear.cgColor,
			UIColor.black.cgColor,
			UIColor.clear.cgColor,
			UIColor.clear.cgColor,
			UIColor.black.cgColor,
			UIColor.clear.cgColor,
		]
		timeScrollWrapper.layer.mask = gradientMask
		timeScrollGradientMask = gradientMask

		let focusMask = gradientMask.clone()
		focusMask.colors = [
			UIColor.clear.cgColor,
			UIColor.clear.cgColor,
			UIColor.black.cgColor,
			UIColor.black.cgColor,
			UIColor.clear.cgColor,
			UIColor.clear.cgColor,
		]
		focusScrollWrapper.layer.mask = focusMask
		focusScrollGradientMask = focusMask

		let focusBackgroundLayer = gradientMask.clone()
		focusBackgroundLayer.colors = [
			UIColor.clear.cgColor,
			UIColor.clear.cgColor,
			UIColor(hexString: "7294b4").withAlphaComponent(0.6).cgColor,
			UIColor(hexString: "949ab0").withAlphaComponent(0.6).cgColor,
			UIColor.clear.cgColor,
			UIColor.clear.cgColor,
		]
		focusScrollWrapper.layer.insertSublayer(focusBackgroundLayer, at: 0)
		focusScrollBackgroundLayer = focusBackgroundLayer
	}

	private func updateGlobeTimeSliderMaskLayers() {
		guard let timeScrollGradientMask, let focusScrollGradientMask, let focusScrollBackgroundLayer else { return }

		let bounds = timeScrollWrapper.bounds
		guard bounds.width > 0, bounds.height > 0 else { return }

		timeScrollGradientMask.frame = bounds
		focusScrollGradientMask.frame = bounds
		focusScrollBackgroundLayer.frame = bounds

		let locations = focusBandMaskLocations(forWidth: bounds.width)
		timeScrollGradientMask.locations = locations
		focusScrollGradientMask.locations = locations
		focusScrollBackgroundLayer.locations = locations
	}

	private func focusBandMaskLocations(forWidth width: CGFloat) -> [NSNumber] {
		let relativeFocusWidth = StyleParams.timeSliderFocusWidth / width
		let focusRectStart = NSNumber(value: Float(0.5 - relativeFocusWidth / 2))
		let focusRectEnd = NSNumber(value: Float(0.5 + relativeFocusWidth / 2))
		return [0, focusRectStart, focusRectStart, focusRectEnd, focusRectEnd, 1]
	}

	func mainTimeScrollNormalizedContentOffsetX() -> CGFloat {
		timeScrollView.contentOffset.x + timeScrollView.contentInset.left
	}

	func mainTimeScrollContentOffsetRange() -> CGFloat {
		let inset = timeScrollView.contentInset
		let viewportWidth = timeScrollView.bounds.width
		let contentWidth = timeScrollView.contentSize.width
		guard viewportWidth > 0, contentWidth > 0 else {
			return GlobeTimeSliderMetrics.maxContentOffsetX(forViewportWidth: viewportWidth)
		}
		return max(0, contentWidth - viewportWidth + inset.left + inset.right)
	}

	func contentOffsetX(forYearIndex yearIndex: Int) -> CGFloat {
		let clamped = min(max(0, yearIndex), GlobeTimeSliderMetrics.yearIndexMax)
		let range = mainTimeScrollContentOffsetRange()
		let normalized = CGFloat(clamped) / CGFloat(GlobeTimeSliderMetrics.yearIndexMax) * range
		return normalized - timeScrollView.contentInset.left
	}
}

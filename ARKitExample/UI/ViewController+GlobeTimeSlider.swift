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
	static let scrollContentRange: CGFloat = 2_800
	static let yearIndexMax = 349
	static let yearLabelTagBase = 1_000
}

extension ViewController {

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

		let yearToPreserve = preserveYear ? currentYear : 0
		let width = timeScrollView.bounds.width
		let widthChanged = abs(width - lastGlobeTimeSliderLayoutWidth) > 0.5

		if widthChanged {
			lastGlobeTimeSliderLayoutWidth = width
			let padding = width / 2 - GlobeTimeSliderMetrics.centerOffset
			var contentRect = CGRect.zero

			for index in 0..<GlobeTimeSliderMetrics.yearLabelCount {
				let frame = CGRect(
					x: padding + CGFloat(index) * GlobeTimeSliderMetrics.yearLabelWidth,
					y: GlobeTimeSliderMetrics.yearLabelY,
					width: GlobeTimeSliderMetrics.yearLabelWidth,
					height: GlobeTimeSliderMetrics.yearLabelHeight
				)
				contentRect = contentRect.union(frame)

				if let mainLabel = timeScrollView.viewWithTag(GlobeTimeSliderMetrics.yearLabelTagBase + index) {
					mainLabel.frame = frame
				}
				if let focusLabel = focusTimeScrollView.viewWithTag(GlobeTimeSliderMetrics.yearLabelTagBase + index) {
					focusLabel.frame = frame
				}
			}

			contentRect.size.width += padding
			timeScrollView.contentSize = contentRect.size
			focusTimeScrollView.contentSize = contentRect.size
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

	func contentOffsetX(forYearIndex yearIndex: Int) -> CGFloat {
		let clamped = min(max(0, yearIndex), GlobeTimeSliderMetrics.yearIndexMax)
		return CGFloat(clamped) / CGFloat(GlobeTimeSliderMetrics.yearIndexMax) * GlobeTimeSliderMetrics.scrollContentRange
	}
}

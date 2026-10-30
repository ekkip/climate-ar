/*
See LICENSE folder for this sample's licensing information.

Abstract:
Layout constants migrated from Main.storyboard (375×667 reference).
*/

import UIKit

enum StyleParams {
	/// Minimum time the launch screen stays visible after the app scene connects.
	static let minimumLaunchScreenDuration: TimeInterval = 1.8

	static let safeAreaMarginBottom: CGFloat = narrowScreen ? 56 : 48
	static let safeAreaMarginTrailing: CGFloat = 36

	static let sceneViewEdgeInset: CGFloat = -1
	static let messagePanelLeading: CGFloat = 15
	static let messagePanelTopFromSafeArea: CGFloat = -5
	static let messageStackPadding: CGFloat = 10
	static let messageStackSpacing: CGFloat = 10

	static let globeControlPanelHeight: CGFloat = 76
	static let globeControlHorizontalInset: CGFloat = 54
	static let globeControlPanelVerticalMargin: CGFloat = 20
	static let screenshotButtonSize: CGFloat = 48
	static let autoplayButtonSize: CGFloat = 48
	static let timeSliderHeight: CGFloat = 36
	static let timeSliderFocusWidth: CGFloat = 77
	/// Panel bottom inset from the root view bottom (fixed pt; not `safeAreaLayoutGuide`).
	/// Matches legacy storyboard spacing and leaves room for the 20 pt touch margin below the visible slider.
	static var timeSliderPanelBottomInsetFromView: CGFloat { safeAreaMarginBottom }
	/// Full-width drag strip: margin + slider + margin (20 + 36 + 20 = 76 pt).
	static var timeSliderTouchRegionHeight: CGFloat {
		timeSliderHeight + 2 * globeControlPanelVerticalMargin
	}

	static let thermometerWidth: CGFloat = 12
	static let thermometerHeight: CGFloat = 552
	static let thermometerLeadingFromSafeArea: CGFloat = 20
	static let thermometerContainerHeight: CGFloat = 258
	static let thermometerMercuryImageHeight: CGFloat = 350
	static let thermometerSidePanelLeadingOffset: CGFloat = 8
//	static let thermometerSidePanelBottomFromSafeArea: CGFloat = 65

	static let co2PanelSize = CGSize(width: 96, height: 82)
	static let threshold1PanelSize = CGSize(width: 54, height: 32)
	static let threshold2PanelSize = CGSize(width: 96, height: 48)
	static let thresholdVerticalGap: CGFloat = 37
	static let co2PanelTopGapFromThreshold1: CGFloat = 40

	static let menuButtonSize: CGFloat = 70
	static let visibleMenuButtonSize: CGFloat = 24
	static let visibleMenuButtonTopMargin: CGFloat = 36
	/// Cover/outer canvas stays below this longest edge; unfolded inner display exceeds it.
	static let innerDisplayLongestEdgeMin: CGFloat = 920
	
	static let switchLabelMargin: CGFloat = 8

//	static let climatePolicyPanelSize = CGSize(width: 190, height: 53)
//	static let climatePolicyBottomFromSafeArea: CGFloat = 65

	static let overlayPanelSize = CGSize(width: 320, height: 480)
	static let menuViewHeight: CGFloat = 300
	static let menuMarginHorizontal: CGFloat = 32
	
	static var narrowScreen: Bool {
		let activeScene = UIApplication.shared.connectedScenes
			.first { $0.activationState == .foregroundActive } as? UIWindowScene
		
		// Fallback to the first window scene if none are currently in focus/foregroundActive
		let targetScene = activeScene ?? (UIApplication.shared.connectedScenes.first as? UIWindowScene)
		
		// Return the physical screen bounds attached to that scene
		let targetBounds = targetScene?.screen.bounds ?? .zero
		
		return min(targetBounds.width, targetBounds.height) < 450
	}
	
	// Colours
	
	static let green = UIColor(red: 0.557, green: 0.827, blue: 0, alpha: 1)
	static let red = UIColor(red: 0.682, green: 0.2, blue: 0.176, alpha: 1)
}

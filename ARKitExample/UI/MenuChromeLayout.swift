/*
See LICENSE folder for this sample's licensing information.

Abstract:
Menu button placement rules for iPhone Duo Dynamic Island occlusion.
*/

import UIKit

enum MenuChromeLayout {

	/// Height of the top strip used to probe occlusion intersection (see Apple ControlsView sample).
	static var occlusionProbeHeight: CGFloat {
		StyleParams.visibleMenuButtonTopMargin + StyleParams.menuButtonSize
	}

	/// Inner unfolded display uses regular size classes in both dimensions.
	/// Outer cover display portrait and inner landscape are the only poses that overlap
	/// the Dynamic Island occlusion region.
	static func shouldDisplaceForDynamicIsland(
		bounds: CGRect,
		horizontalSizeClass: UIUserInterfaceSizeClass,
		verticalSizeClass: UIUserInterfaceSizeClass
	) -> Bool {
		guard bounds.width > 0, bounds.height > 0 else { return false }

		let isPortrait = bounds.height > bounds.width
		let isLandscape = bounds.width > bounds.height
		let isInnerDisplay = horizontalSizeClass == .regular && verticalSizeClass == .regular
		let isCoverDisplayCanvas = max(bounds.width, bounds.height) < StyleParams.innerDisplayLongestEdgeMin

		if isInnerDisplay, isLandscape {
			return true
		}
		if isPortrait, !isInnerDisplay || isCoverDisplayCanvas {
			return true
		}
		return false
	}

	/// Matches Apple’s `ControlsView.updateConstraints()` occlusion padding.
	@available(iOS 27.1, *)
	static func occlusionTopInset(for view: UIView, shouldDisplace: Bool) -> CGFloat? {
		guard shouldDisplace, view.bounds.width > 0 else { return nil }

		let barFrame = CGRect(
			x: 0,
			y: 0,
			width: view.bounds.width,
			height: occlusionProbeHeight
		)
		
		return view.reservedRegions(kind: .occlusion)
			.filter { $0.frame.intersects(barFrame) }
			.map(\.frame.maxY)
			.max()
		
//		view.reservedRegions(kind: .occlusion).filter { $0.frame.intersects(barFrame) }.forEach {
//			print("\(#function) – occlusion frame: \($0.frame ?? .zero)")
//		}
//		
//		
//		return view.reservedRegions(kind: .occlusion)
//			.filter { $0.frame.intersects(barFrame) }
//			.first?
//			.frame.maxY
	}
}

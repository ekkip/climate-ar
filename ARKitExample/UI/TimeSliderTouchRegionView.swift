/*
See LICENSE folder for this sample's licensing information.

Abstract:
Full-width touch strip around the time slider: margin bands pan the scroll view;
the center passes hits through to the inset scroll view.
*/

import UIKit

final class TimeSliderTouchRegionView: UIView {
	
	weak var scrollView: UIScrollView?
	
	/// Called after margin-band pans change `scrollView.contentOffset` (main scroll delegate is not invoked).
	var onScrollOffsetChanged: (() -> Void)?
	
	private var panStartOffsetX: CGFloat = 0
	
	private lazy var panRecognizer: UIPanGestureRecognizer = {
		let gr = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
		gr.maximumNumberOfTouches = 1
		return gr
	}()
	
	override init(frame: CGRect) {
		super.init(frame: frame)
		addGestureRecognizer(panRecognizer)
	}
	
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
	
	override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
		guard bounds.contains(point), !isHidden, alpha > 0.01, isUserInteractionEnabled else {
			return nil
		}
		if let scroll = scrollView {
			let scrollFrame = scroll.convert(scroll.bounds, to: self)
			if scrollFrame.contains(point) {
				return nil
			}
		}
		return self
	}
	
	@objc private func handlePan(_ recognizer: UIPanGestureRecognizer) {
		guard let scroll = scrollView else { return }
		switch recognizer.state {
		case .began:
			panStartOffsetX = scroll.contentOffset.x
		case .changed:
			let deltaX = recognizer.translation(in: self).x
			var offsetX = panStartOffsetX - deltaX
			let maxX = max(0, scroll.contentSize.width - scroll.bounds.width)
			offsetX = min(max(0, offsetX), maxX)
			scroll.contentOffset.x = offsetX
			onScrollOffsetChanged?()
		default:
			break
		}
	}
}

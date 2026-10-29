//
//  Extensions.swift
//  ARKitExample
//
//  Created by Ekkehard Petzold on 31.10.17.
//  Copyright © 2017 Apple. All rights reserved.
//

import Foundation
import UIKit


extension CAGradientLayer {
	func clone() -> CAGradientLayer {
		do {
			let data = try NSKeyedArchiver.archivedData(withRootObject: self, requiringSecureCoding: false)
//			return NSKeyedUnarchiver.unarchiveObject(with: data) as! CAGradientLayer
			return try NSKeyedUnarchiver.unarchivedObject(ofClass: CAGradientLayer.self, from: data) ?? CAGradientLayer()
		}
		catch {
			return CAGradientLayer()
		}
		
	}
}

extension Collection {
	
	/// Returns the element at the specified index iff it is within bounds, otherwise nil.
	subscript (safe index: Index) -> Element? {
		return indices.contains(index) ? self[index] : nil
	}
}

extension UIColor {
	convenience init(hexString: String) {
		let hex = hexString.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
		var int = UInt32()
		Scanner(string: hex).scanHexInt32(&int)
		let a, r, g, b: UInt32
		switch hex.count {
		case 3: // RGB (12-bit)
			(a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
		case 6: // RGB (24-bit)
			(a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
		case 8: // ARGB (32-bit)
			(a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
		default:
			(a, r, g, b) = (255, 0, 0, 0)
		}
		self.init(red: CGFloat(r) / 255, green: CGFloat(g) / 255, blue: CGFloat(b) / 255, alpha: CGFloat(a) / 255)
	}
}

extension UIFont {
	
	enum FontStyle: String {
		case light = "Light"
		case regular = "Regular"
		case medium = "Medium"
		case mediumItalic = "MediumItalic"
	}
	
	static func rubik(_ style: FontStyle, size: CGFloat) -> UIFont {
		
		if let font = UIFont(name: UIFont.rubikName(style), size: size) {
//			debugPrint("Found Rubik font")
			return font
		}
		return UIFont.systemFont(ofSize: size)
	}
	
	static func rubikName(_ style: FontStyle) -> String {
		return "Rubik-\(style.rawValue)"
	}
}

extension UILabel {
	func clone() -> UILabel {
		let data = NSKeyedArchiver.archivedData(withRootObject: self)
		return NSKeyedUnarchiver.unarchiveObject(with: data) as! UILabel
		
//		do {
//			let data = try NSKeyedArchiver.archivedData(withRootObject: self, requiringSecureCoding: false)
//
//			guard let clone = try NSKeyedUnarchiver.unarchivedObject(ofClass: UILabel.self, from: data) else { return UILabel() }
//			return clone
//		}
//		catch {
//			return UILabel()
//		}
	}
}

extension UIPageControl {
	func goTo(_ page: Int) {
		currentPage = page
		updateCurrentPageDisplay()
	}
}

extension UIView {

	func pinEdges(to view: UIView, insets: UIEdgeInsets = .zero) {
		translatesAutoresizingMaskIntoConstraints = false
		NSLayoutConstraint.activate([
			topAnchor.constraint(equalTo: view.topAnchor, constant: insets.top),
			leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: insets.left),
			trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -insets.right),
			bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -insets.bottom),
		])
	}

	func pinEdges(to layoutGuide: UILayoutGuide, insets: UIEdgeInsets = .zero) {
		translatesAutoresizingMaskIntoConstraints = false
		NSLayoutConstraint.activate([
			topAnchor.constraint(equalTo: layoutGuide.topAnchor, constant: insets.top),
			leadingAnchor.constraint(equalTo: layoutGuide.leadingAnchor, constant: insets.left),
			trailingAnchor.constraint(equalTo: layoutGuide.trailingAnchor, constant: -insets.right),
			bottomAnchor.constraint(equalTo: layoutGuide.bottomAnchor, constant: -insets.bottom),
		])
	}

	static func barView(cornerRadius: CGFloat = 1) -> UIView {
		let bar = UIView()
		bar.backgroundColor = .white
		bar.layer.cornerRadius = cornerRadius
		bar.layer.masksToBounds = true
		return bar
	}

	func fadeTransition(_ duration:CFTimeInterval) {
		let animation = CATransition()
		animation.timingFunction = CAMediaTimingFunction(name:
			CAMediaTimingFunctionName.easeInEaseOut)
		animation.type = CATransitionType.fade
		animation.duration = duration
		layer.add(animation, forKey: CATransitionType.fade.rawValue)
	}
}

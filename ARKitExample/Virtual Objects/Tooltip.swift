//
//  Tooltip.swift
//  ARKitExample
//
//  Created by Ekkehard Petzold on 28.11.17.
//  Copyright © 2017 Apple. All rights reserved.
//

import UIKit
import SceneKit
import SpriteKit

class Tooltip: SCNNode {

	var lon = 0
	var lat = 0
	
	var descriptionLabel = SKLabelNode()
	var valueLabel = SKLabelNode()
	var planeContainer = SCNNode()
	
	var currentAlignment: SKLabelHorizontalAlignmentMode = .left
	
	// TODO: Evaluate the use of SCNTexts instead of SKLabelNodes
//	var descriptionText = SCNText()
//	var valueText = SCNText()


	func setup(lon: Int, lat: Int, description: String, value: Float) {

		self.lon = lon
		self.lat = lat
		
		let tooltipScale: CGFloat = 0.175 // Tooltip appearance
		let sceneScale: CGFloat = 10_000
//		let scenePadding: CGFloat = 0.005 * sceneScale

		descriptionLabel = SKLabelNode(text: description)
		descriptionLabel.position = CGPoint(x: 0, y: 0.01 * sceneScale)
		descriptionLabel.fontName = UIFont.rubikName(.regular)
		descriptionLabel.fontSize = 0.025 * sceneScale
		descriptionLabel.fontColor = .white
		descriptionLabel.horizontalAlignmentMode = currentAlignment
		descriptionLabel.verticalAlignmentMode = .bottom
		descriptionLabel.name = "Description"
		debugPrint("Description frame: \(descriptionLabel.frame), \(descriptionLabel.horizontalAlignmentMode == .center)")

		valueLabel = SKLabelNode(text: formatted(value))
		valueLabel.fontName = UIFont.rubikName(.medium)
		valueLabel.fontSize = 0.04 * sceneScale
			valueLabel.fontColor = .white
		valueLabel.horizontalAlignmentMode = currentAlignment
		valueLabel.verticalAlignmentMode = .top
		valueLabel.name = "Value"
		debugPrint("Value frame: \(valueLabel.frame)")

		let contentSize = CGSize(width: max(0.4 * sceneScale, 2 * descriptionLabel.frame.size.width), height: 2.4 * valueLabel.frame.size.height)
//		let containerFrame = CGRect(x: -scenePadding, y: -scenePad	ding, width: contentSize.width + 2*scenePadding, height: contentSize.height + 2*scenePadding)
//
//		let background = SKShapeNode(path: CGPath(roundedRect: containerFrame, cornerWidth: scenePadding/2, cornerHeight: scenePadding/2, transform: nil))
//		background.fillColor = UIColor(white: 0, alpha: 0.2)
		
		let scene = SKScene(size: contentSize)
		scene.backgroundColor = .clear //UIColor(white: 0, alpha: 0.2)
		scene.anchorPoint = CGPoint(x: 0.5, y: 0.5)
		debugPrint("Scene with size \(scene.size), anchor point \(scene.anchorPoint)")

		scene.addChild(descriptionLabel)
		scene.addChild(valueLabel)

		debugPrint("Scene's scaling mode: \(scene.scaleMode.rawValue)")
		
		let sceneSize = scene.size * tooltipScale / sceneScale
		
		let plane = SCNPlane(width: sceneSize.width, height: sceneSize.height)

		plane.firstMaterial?.diffuse.contents = scene
		plane.firstMaterial?.diffuse.contentsTransform = SCNMatrix4Translate(SCNMatrix4MakeScale(1, -1, 1), 0, 1, 0)
//		plane.firstMaterial?.lightingModel = .constant
		plane.firstMaterial?.lightingModel = .physicallyBased
		plane.firstMaterial?.isDoubleSided = false
		
		debugPrint("Plane's bounding box: \(plane.boundingBox)")
		
		planeContainer = SCNNode(geometry: plane)
		planeContainer.localTranslate(by: SCNVector3(0, (lat < 90 ? 1 : -1) * plane.height / 2, 0))
		debugPrint("Plane container's bounding box: \(planeContainer.boundingBox)")
		
		
		addChildNode(planeContainer)
		
		scale = SCNVector3Uniform(Float(3))
	}
	
	func set(_ value: Float) {
		let text = formatted(value * Const.cco2MassFactor)
		if valueLabel.text != text {
			valueLabel.text = text
		}
	}

	func align(for deviation: Float) {
		
		if abs(deviation) < .pi / 36 { return }
		
		let alignment: SKLabelHorizontalAlignmentMode = deviation > 0 ? .left : .right
		if alignment == currentAlignment { return }
		currentAlignment = alignment

		planeContainer.runAction(SCNAction.fadeOpacity(to: 0, duration: 0.125)) {
			self.descriptionLabel.horizontalAlignmentMode = alignment
			self.valueLabel.horizontalAlignmentMode = alignment
			self.planeContainer.runAction(SCNAction.fadeOpacity(to: 1, duration: 0.125))
		}
		
//		SCNTransaction.begin()
//
//		planeContainer.rotation = SCNVector4Make(0, alignment == .left ? 1 : -1, 0, .pi)
//
//		SCNTransaction.animationDuration = 0.2
//		SCNTransaction.completionBlock = {
//			self.descriptionLabel.horizontalAlignmentMode = alignment
//			self.valueLabel.horizontalAlignmentMode = alignment
//			self.planeContainer.rotation = SCNVector4Make(0, 1, 0, 0)
//		}
//		SCNTransaction.commit()
		
	}
	
	private func formatted(_ value: Float) -> String {
		return String(format: "%.0f Mt", value)
	}
}

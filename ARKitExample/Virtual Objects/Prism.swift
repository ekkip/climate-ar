//
//  Prism.swift
//  ARKitExample
//
//  Created by Ekkehard Petzold on 30.10.17.
//  Copyright © 2017 Apple. All rights reserved.
//

import UIKit
import ARKit
import SceneKit

class Prism: SCNNode {
	
	var baseRadius: Float = 0
	var scaleCorrection: Float = 1
	var years = [Float]()
	var years26 = [Float]()
	var gridContainer = SCNNode()
	
//	static let houdiniConversion: Float = 1 / 500
	static let houdiniConversion: Float = 1 / 400
	
	let threshold: Float = 0.03
	let widthSocket: Float = 0.75 * houdiniConversion
	let widthFactor: Float = 0.000_8 * houdiniConversion
	let heightFactor: Float = 0.05 * houdiniConversion
	
	override init() {
//		super.init(modelName: "prism", fileExtension: "scn")
		super.init()
		
//		if let container = childNodes.first, let scaler = container.childNodes.first {
//
//		}
		
	}
	
	required init?(coder aDecoder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	var climatePolicy: Bool = false
	var scenarioOffset: Int { return years.count - years26.count }
	func yearValue(_ year: Int) -> Float {
		
		if (year >= scenarioOffset) && climatePolicy {
			return years26[year-scenarioOffset]
		}
		return years[year]
	}
	
	func loadModel() {
		
		guard let virtualObjectScene = SCNScene(named: "prism.scn", inDirectory: "Models.scnassets/globe") else {
			print("Could not import Models.scnassets/globe/prism.scn")
			return
		}
		
//		let wrapperNode = SCNNode()
		
		for child in virtualObjectScene.rootNode.childNodes {
			if let geometry = child.geometry {
				print("Child node \(child.name ?? "<unnamed>") has geometry.")
				if let firstMaterial = geometry.firstMaterial {
					debugPrint("Found firstMaterial, setting lightingModel …")
					firstMaterial.lightingModel = .physicallyBased
				}
				else {
					print("Geometry has no first material!")
				}
			}
			else {
				print("Child node \(child.name ?? "<unnamed>") has NO geometry!")
			}
			child.movabilityHint = .movable
			self.addChildNode(child)
		}
//		self.addChildNode(wrapperNode)
	}

	func setPosition(_ lon: Int, _ lat: Int) {
		let lonArc = Float.pi * (Float(lon) + 0.5) / 180
		let latArc = Float.pi * (Float(lat) + 0.5) / 180

		self.eulerAngles.x = latArc
		self.eulerAngles.y = lonArc
	}
	
	func setYear(_ year: Int, forceResize: Bool = false) {
		
		guard let prism = childNodes.first else {
			debugPrint("Prism root node »\(self.name ?? "---")« contains no child nodes.")
			return
		}

		guard years.count > year else {
//			prism.isHidden = true
//			prism.opacity = 0
			self.removeFromParentNode()
			return
		}
		
		let value = yearValue(year)//years[year]

		let aboveThreshold = value > threshold
		
		if !aboveThreshold && /*prism.opacity == 0*/ !visible && !forceResize {
//			prism.isHidden = true
			return
		}
		
//		prism.isHidden = false
//		prism.opacity = aboveThreshold ? 1 : 0
		if aboveThreshold {
			if !visible {
				makeVisible()
			}
		}
		else {
			if visible {
				makeInvisible()
			}
		}

//		let height = value / 8_000
//		let width = pow(value, 1/4) / 1_500
		let height = value * heightFactor
		let width = widthSocket + value * widthFactor

		prism.scale = SCNVector3(width, height, width) * scaleCorrection
		prism.position.y = baseRadius + 0.5 * height
		
		setTooltip(value: value, y: baseRadius * 1.03 + height * 1.005)
		
//		guard years.count > year else {
//			prism.opacity = 0
//			return
//		}
//
//		let value = years[year]
//
//		let aboveThreshold = value > 10
//
//		let changeOpacity = aboveThreshold != (prism.opacity > 0)
//
//		let height = value / 10_000
//		let width = pow(value, 0.1) / 800
//
//		prism.scale = SCNVector3(width, height, width) * scaleCorrection
//		prism.position.y = baseRadius + 0.5 * height
//
//		if changeOpacity {
//			prism.opacity = aboveThreshold ? 1 : 0
//		}

	}


	func addToContainer(for year: Int) {
		if /*years[year]*/ yearValue(year) > threshold && self.parent == nil {
			gridContainer.addChildNode(self)
		}
	}
	
	func removeFromContainer(for year: Int) {
		if /*years[year]*/ yearValue(year) <= threshold && self.parent != nil {
			self.removeFromParentNode()
		}
	}

	var visible: Bool {
		return opacity > 0
	}
	
	func makeVisible() {
		opacity = 1
	}
	
	func makeInvisible() {
		opacity = 0
	}

	// MARK: - Tooltip
	
	var tooltip: Tooltip?
	
	func addTooltip(lon: Int, lat: Int, description: String) {
		let tooltip = Tooltip()
		tooltip.setup(lon: lon, lat: lat, description: description, value: years.first ?? 0)
		let constraint = SCNBillboardConstraint()
		constraint.freeAxes = [.Y]
		tooltip.constraints = [constraint]

//		let text = SCNText.init(string: description, extrusionDepth: 0.5)
//		text.containerFrame = CGRect(x: 0, y: 0, width: 256, height: 44)
//		text.font = UIFont.rubik(.regular, size: 11)
//		text.firstMaterial?.diffuse.contents = UIColor.orange
////		text.subdivisionLevel = 3
//		let textNode = SCNNode.init(geometry: text)
//		textNode.name = "Tooltip"
//		debugPrint("Tooltip's bounding box: \(textNode.boundingBox)")
//
//		let constraint = SCNLookAtConstraint()
//		constraint.isGimbalLockEnabled = true
//		textNode.constraints = [constraint]

		addChildNode(tooltip)
		
		self.tooltip = tooltip
	}
	
	func setTooltip(value: Float, y: Float) {
		guard let tooltip = tooltip else { return }

		tooltip.position.y = y
		tooltip.set(value)
		
		for childNode in childNodes {
			debugPrint("\(#function) – \(childNode.name ?? "---")'s bounding box: \(childNode.boundingBox)")
		}
	}
	
//	var visible: Bool {
//		return parent != nil
//	}
//
//	func makeVisible() {
//		gridContainer.addChildNode(self)
//	}
//
//	func makeInvisible() {
//		self.removeFromParentNode()
//	}
}

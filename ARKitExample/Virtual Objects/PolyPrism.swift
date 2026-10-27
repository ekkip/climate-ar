//
//  PolyPrism.swift
//  ARKitExample
//
//  Created by Ekkehard Petzold on 17.11.17.
//  Copyright © 2017 Apple. All rights reserved.
//

import UIKit
import SceneKit

class PolyPrism: SCNNode {
	
	var baseRadius: Float = 0
	var scaleCorrection: Float = 1
	var years = [SCNNode]()
	var yearsVisible = [Bool]()
	var gridContainer = SCNNode()
	
	static let houdiniConversion: Float = 1 / 500
	
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
	
	func loadModel(for years: [Float]) {
		gridContainer.addChildNode(self)
		var index = 0
		for yearValue in years {
			loadPrism(for: index, value: yearValue)
			index += 1
		}
	}
	
	func loadPrism(for year: Int, value: Float) {
			
		guard let virtualObjectScene = SCNScene(named: "prism.scn", inDirectory: "Models.scnassets/globe") else {
			print("Could not import Models.scnassets/globe/prism.scn")
			return
		}
		
		//		let wrapperNode = SCNNode()
		
		let prism = SCNNode()
		
		let aboveThreshold = value > threshold
		

		if aboveThreshold {
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
				prism.addChildNode(child)
			}
			setSize(prism, value: value)
		}

		if year == 0 {
			addChildNode(prism)
		}
		years.append(prism)
		yearsVisible.append(aboveThreshold)
	}
	
	func setPosition(_ lon: Int, _ lat: Int) {
		let lonArc = Float.pi * (Float(lon) + 0.5) / 180
		let latArc = Float.pi * (Float(lat) + 0.5) / 180
		
		self.eulerAngles.x = latArc
		self.eulerAngles.y = lonArc
	}
	
	func setSize(_ prism: SCNNode, value: Float) {
		
		//		let height = value / 8_000
		//		let width = pow(value, 1/4) / 1_500
		let height = value * heightFactor
		let width = widthSocket + value * widthFactor
		
		prism.scale = SCNVector3(width, height, width) * scaleCorrection
		prism.position.y = baseRadius + 0.5 * height
		
		
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
	
	var currentYear: Int = 0
	
	func setYear(_ year: Int) {
		if year == currentYear { return }
		
		removeYear(currentYear)
		addYear(year)
	}
	
	func addYear(_ year: Int) {
		if yearsVisible[year] {
			addChildNode(years[year])
		}
	}

	func removeYear(_ year: Int) {
		if yearsVisible[year] {
			years[year].removeFromParentNode()
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

//
//  HexPrism.swift
//  ARKitExample
//
//  Created by Ekkehard Petzold on 03.11.17.
//  Copyright © 2017 Apple. All rights reserved.
//

import UIKit
import SceneKit

class HexPrism: SCNNode {

	var container = SCNNode()
	var hexShape: SCNShape
	
	var baseRadius: Float = 0
	var scaleCorrection: Float = 1
	var years = [Float]()
	
	override init() {
		let hexPath = UIBezierPath.init(cgPath: polygonPath(center: .zero, radius: 1, sides: 6, offset: 0))
		hexShape = SCNShape(path: hexPath, extrusionDepth: 0)
		let material = SCNMaterial()
		material.diffuse.contents = #colorLiteral(red: 1, green: 0.9803921569, blue: 0.9411764706, alpha: 1)
		material.lightingModel = .physicallyBased
		hexShape.firstMaterial = material
		
		
		super.init()
		
		container = SCNNode(geometry: hexShape)
		addChildNode(container)
	}
	
	required init?(coder aDecoder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
	
	func setPosition(_ lat: Int, _ lon: Int) {
		let latArc = Float.pi * (Float(lat) + 0.5) / 180
		let lonArc = Float.pi * (Float(lon) + 0.5) / 180
		
		self.eulerAngles.x = lonArc
		self.eulerAngles.y = latArc
	}
	
	func setYear(_ year: Int, forceResize: Bool = false) {
		
		guard years.count > year else {
			//			prism.isHidden = true
			opacity = 0
			return
		}
		
		let value = years[year]
		
		let aboveThreshold = value > 10
		
		if !aboveThreshold && opacity == 0 && !forceResize {
			//			prism.isHidden = true
			return
		}
		
		//		prism.isHidden = false
		opacity = aboveThreshold ? 1 : 0
		
		let height = value / 10_000
//		let width = pow(value, 0.2) / 800
		
		hexShape.extrusionDepth = CGFloat(height * scaleCorrection)
		container.position.y = baseRadius + 0.5 * height
	}
}

//
//  Globe.swift
//  ARKitExample
//
//  Created by Ekkehard Petzold on 16.09.17.
//  Copyright © 2017 Apple. All rights reserved.
//

import Foundation
import ARKit
import SceneKit

class Globe: VirtualObject {
	
	var prisms = [Prism]()
	var coreGlobe: SCNNode?
	var gridContainer: SCNNode?
	
//	var tooltips = [Tooltip]()
	var prismsWithTooltips = [Prism]()
	var displayTooltips = true

	var currentYear = 0
	
	override init() {
		super.init(modelName: "globe", fileExtension: "scn", thumbImageFilename: "globe", title: "Globe")
	}
	
	required init?(coder aDecoder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
	
	override func loadModel() {
		super.loadModel()
		
		displayTooltips = UserDefaults.standard.bool(for: .displayLocalData)
		
//		var optionalGlobe: SCNNode?
		debugPrint("Globe scene »\(self.name ?? "---")« has \(self.childNodes.count) child nodes.")
		
		guard let wrapperNode = self.childNodes.first else { return }
		
		for childNode in wrapperNode.childNodes {
			debugPrint("childNode: \(childNode.name ?? "---")")
			switch childNode.name ?? "---" {
			case "Grid Container":
				self.gridContainer = childNode
			case "Globe":
				self.coreGlobe = childNode
			default:
				break
			}
		}
		
		guard let globe = self.coreGlobe, let gridContainer = self.gridContainer else {
			debugPrint("Child nodes missing from the Globe scene.")
			return
		}
		
		let prismTemplate = Prism()
		prismTemplate.loadModel()
		let scaleCorrection = 1 / (prismTemplate.boundingBox.max.y - prismTemplate.boundingBox.min.y)
		debugPrint("prism scale correction: \(scaleCorrection)")
		
		let globeRadius = globe.scale.x * fabsf(globe.boundingBox.max.x - globe.boundingBox.min.x) / 2
		debugPrint("globeRadius \(globeRadius) = \(globe.scale.x) * (\(globe.boundingBox.max.x) - \(globe.boundingBox.min.x) / 2 ")
		
		
//		debugPrint("Loaded prism template, \(prismTemplate.childNodes.count) child nodes")

		let filename = "REMIND_BASE_v02_ACCU"
		let filename26 = "REMIND_26_v02_ACCU"

		let prominentAreas = [
			61: [55: "Los Angeles Area"],
			92: [48: "Chicago Area"],
//			105: [48: "New York Area"],
			121: [124: "Buenos Aires Area"],
			179: [38: "London Area"],
			207: [116: "Johannesburg Area"],
			219: [68: "Mekka Area"],
//			306: [52: "Seoul Area"],
			319: [54: "Tokyo Area"],
			331: [123: "Sydney Area"]
		]
		
		
		if let path = Bundle.main.path(forResource: filename, ofType: "json"), let path26 = Bundle.main.path(forResource: filename26, ofType: "json") {
			do {
				let data = try Data(contentsOf: URL(fileURLWithPath: path), options: .mappedIfSafe)
				let jsonResult = try JSONSerialization.jsonObject(with: data, options: .mutableLeaves)
				let data26 = try Data(contentsOf: URL(fileURLWithPath: path26), options: .mappedIfSafe)
				let jsonResult26 = try JSONSerialization.jsonObject(with: data26, options: .mutableLeaves)

//				let data26 = try Data(contentsOf: URL(fileURLWithPath: path26), options: .mappedIfSafe)
//				let jsonResult26 = try JSONSerialization.jsonObject(with: data26, options: .mutableLeaves)
				
//                if let _ = jsonResult as? [String: [String: [Float]]] {
//                    debugPrint("jsonResult can be interpreted as [String: [String: [Float]]]")
//                }
//                else if let _ = jsonResult as? [String: [String: [Double]]] {
//                    debugPrint("jsonResult can be interpreted as [String: [String: [Double]]]")
//                }
//                else if let _ = jsonResult as? [String: [String: [Int]]] {
//                    debugPrint("jsonResult can be interpreted as [String: [String: [Int]]]")
//                }
//                else if let _ = jsonResult as? [String: [String: [Any]]] {
//                    debugPrint("jsonResult can be interpreted as [String: [String: [Any]]]")
//                }

                if let yearsByGrid = jsonResult as? [String: [String: [Double]]], let yearsByGrid26 = jsonResult26 as? [String: [String: [Double]]] {
					debugPrint("\(yearsByGrid.count) LATs")
					for latString in yearsByGrid.keys {
						if let latDict = yearsByGrid[latString], let latDict26 = yearsByGrid26[latString] {
							debugPrint("\(latDict.count) LONs")
							for lonString in latDict.keys {
								if let years = latDict[lonString], let years26 = latDict26[lonString], let lon = Int(lonString), let lat = Int(latString) {
									let prism: Prism = prismTemplate.clone()
									
//									prism.printNodeHierarchy()
									
//									if let total = years.last, total > 10_000 {
//									if lon == 182, lat == 42 { // Rural France
									if lon == 319, lat == 54 { // Tokyo area
										debugPrint("Annual accumulations for (\(lon),\(lat)): \(years)")
//										if  let geometry = prism.childNodes.first?.geometry {
//											geometry.firstMaterial?.diffuse.contents = UIColor.red
//										}
									}
									if let lastValue = years.last, lastValue > 20_000 {
										debugPrint("lon \(lon) lat \(lat) – \(89.5-Float(lat)), \(Float(lon)-179.5): last value \(lastValue)")
									}
									
									
//									debugPrint("Cloned prism template with \(prism.childNodes.count) child node(s)")
//									let prism = HexPrism()
									prism.baseRadius = globeRadius
									prism.scaleCorrection = scaleCorrection
									prism.years = years.map { Float($0) }
									prism.years26 = years26.map { Float($0) }
									prism.gridContainer = gridContainer
//									debugPrint("FLAG 0: Setting up cloned prism with \(prism.childNodes.count) child node(s)")
									prism.setPosition(lon, lat)
//									debugPrint("FLAG 1: Setting up cloned prism with \(prism.childNodes.count) child node(s)")
									prism.setYear(currentYear, forceResize: true)
									
									if let prominentArea = prominentAreas[lon]?[lat] {
//										tooltips.append(prism.addTooltip(lon: lon, lat: lat, description: prominentArea))
										prism.addTooltip(lon: lon, lat: lat, description: prominentArea)
										prismsWithTooltips.append(prism)
									}
									
//									debugPrint("Set up cloned prism with \(prism.childNodes.count) child node(s)")
//									gridContainer.addChildNode(prism)
									prisms.append(prism)
								}
							}
						}
					}
				}
                else {
                    debugPrint("jsonResult cannot be interpreted.")
                }
			} catch {
				// handle error
                debugPrint("Something went wrong.")
			}
		}
		else {
			debugPrint("DATA FILE MISSING")
		}
		
		
		
//		for lon in 0..<180 {
//			for lat in 0..<360 {
//				let prism: Prism = prismTemplate.clone()
//				prism.baseRadius = globeRadius
//				prism.scaleCorrection = scaleCorrection
////				debugPrint("Cloned the prism template, \(prism.childNodes.count) child nodes")
//				prism.setPosition(lat, lon)
//				prism.setValue(Float(pow(drand48(),3)*100))
//
//				if drand48() > 0.8 {
//					gridContainer.addChildNode(prism)
//				}
////				debugPrint("Added prism, angles: \(prism.eulerAngles) > \(prism.childNodes.first?.eulerAngles ?? SCNVector3()), scale: \(prism.scale) > \(prism.childNodes.first?.scale ?? SCNVector3())")
//			}
//		}

		
		
		
		
//		let rotation = SCNAction.rotateBy(x: 0, y: CGFloat.pi, z: 0, duration: 15)
//		let loop = SCNAction.repeatForever(rotation)
//		self.runAction(loop)
		
		debugPrint("Grid container contains \(gridContainer.childNodes.count) child nodes. Prisms array contains \(prisms.count) prisms.")
		
		for year in [2020, 2021] {
			let values = prisms.map({ $0.yearValue(year-1750) }).sorted()
			print("Year \(year):")
			print("max: \(values.last ?? -1)")
			print("sum: \(values.reduce(0, +))")
//			print(values.map({String($0)}).joined(separator: ", "))
			for minimum in [Float(0), 1, 10, 100, 250, 500, 1000] {
				print(">= \(minimum): \(values.filter({ $0 >= minimum }).count)")
			}
		}
	}
	
	var animating = false
	var queuedYear: Int?
	
	var climatePolicy = false
	func setYear(_ year: Int, climateSimulation: Bool? = nil) {
		
		if year == currentYear && (climateSimulation == nil || climateSimulation == climatePolicy) {
			return
		}
		if let simulation = climateSimulation {
			climatePolicy = simulation
			setClimatePolicySimulation(climatePolicy)
		}
		
		if animating {
			queuedYear = year
			return
		}
		
		animating = true
		currentYear = year
		
		for prism in prisms {
			prism.addToContainer(for: year)
		}
		
		SCNTransaction.begin()
		
//		for gridChild in gridContainer.childNodes {
//			if let prism = gridChild as? Prism {
//				prism.setYear(year)
//			}
//		}
		
		debugPrint("Setting year \(year) (\(year+1750)) for \(prisms.count) prisms …")
		debugPrint("years.count: \(prisms.first?.years.count ?? -1)")
		debugPrint("years26.count: \(prisms.first?.years26.count ?? -1)")
		
		for prism in prisms {
//			debugPrint("Setting year for prism with \(prism.childNodes.count) child nodes")
			prism.setYear(year)
		}
		
		
		SCNTransaction.animationDuration = 0.5
		SCNTransaction.animationTimingFunction = CAMediaTimingFunction.init(name: CAMediaTimingFunctionName.linear)
		SCNTransaction.completionBlock = {
			self.animating = false
			if let queuedYear = self.queuedYear {
				self.setYear(queuedYear)
				self.queuedYear = nil
			}
		}
		SCNTransaction.commit()
		
		for prism in prisms {
			prism.removeFromContainer(for: year)
		}
	}
	
	func setClimatePolicySimulation(_ on: Bool) {
		for prism in prisms { prism.climatePolicy = on }
	}
	
	func adjustTooltipAligments(viewingAngle: Float, cameraDistance: Float) {
//		debugPrint("\(#function) – viewing angle: \(viewingAngle)")
		var firstTooltip = true
		for prism in prismsWithTooltips {
			if let tooltip = prism.tooltip {
				if displayTooltips {
					if tooltip.parent == nil {
						prism.addChildNode(tooltip)
					}
					let deviation = (Float(tooltip.lon) - 179.5) * .pi / 180 - viewingAngle
					tooltip.align(for: deviation.modulo(from: -.pi, to: .pi))
					
//					tooltip.scale = SCNVector3Uniform(cameraDistance * 10)
//					tooltip.scene.setScale(CGFloat(cameraDistance))
//					tooltip.setPlaneScale(scale: cameraDistance	)
					
					if firstTooltip {
//						debugPrint("\(tooltip.descriptionLabel.text ?? "---") – lon: \(tooltip.lon - 180), deviation: \(deviation.modulo(from: -.pi, to: .pi))")
//                        debugPrint("\(tooltip.descriptionLabel.text ?? "---") – tooltip scale: \(tooltip.scale)")
						firstTooltip = false
					}
				}
				else {
					if tooltip.parent != nil {
						tooltip.removeFromParentNode()
					}
				}
			}
		}
	}
	
}

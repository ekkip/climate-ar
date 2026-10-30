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
	
	func yearValue(_ year: Int, climatePolicy policy: Bool? = nil) -> Float {
		let usePolicy = policy ?? climatePolicy
		if (year >= scenarioOffset) && usePolicy {
			return years26[year - scenarioOffset]
		}
		return years[year]
	}
	
	private static let policyValueEpsilon: Float = 0.000_1
	private static let geometryEpsilon: Float = 0.000_001
	
	private static func vectorNear(_ a: SCNVector3, _ b: SCNVector3, epsilon: Float) -> Bool {
		return abs(a.x - b.x) <= epsilon && abs(a.y - b.y) <= epsilon && abs(a.z - b.z) <= epsilon
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

	/// SCNNode.clone() shares geometry across all prisms; scaling one node can force global bounds work on shared meshes.
	func privatizeSharedGeometry() {
		for child in childNodes {
			guard let shared = child.geometry else { continue }
			child.geometry = shared.copy() as? SCNGeometry
		}
	}
	
	/// Merged-renderer mode: the mesh is drawn by `MergedPrismLayer`; this node only carries a tooltip.
	func hideOwnMesh() {
		childNodes.first?.isHidden = true
	}
	
	func updateTooltipAnchor(year: Int) {
		guard years.count > year else {
			isHidden = true
			return
		}
		let value = yearValue(year)
		isHidden = value <= threshold
		setTooltip(value: value, y: baseRadius * 1.03 + value * heightFactor * 1.005)
	}
	
	/// Detached prisms that stay below threshold for both scenarios need no SceneKit work on policy toggle.
	func shouldSkipPolicyToggle(year: Int, previousClimatePolicy: Bool) -> Bool {
		guard years.count > year else { return true }
		let oldValue = yearValue(year, climatePolicy: previousClimatePolicy)
		let newValue = yearValue(year)
		if oldValue <= threshold && newValue <= threshold && parent == nil {
			return true
		}
		return false
	}
	
	func setPosition(_ lon: Int, _ lat: Int) {
		let lonArc = Float.pi * (Float(lon) + 0.5) / 180
		let latArc = Float.pi * (Float(lat) + 0.5) / 180

		self.eulerAngles.x = latArc
		self.eulerAngles.y = lonArc
	}
	
	func setYear(_ year: Int, forceResize: Bool = false, policyToggleAtFixedYear: Bool = false, previousClimatePolicy: Bool? = nil) {
		#if DEBUG
		if ClimatePolicyPerf.isPolicyUpdateActive, policyToggleAtFixedYear {
			ClimatePolicyPerf.prismCounters.prismsVisited += 1
		}
		#endif
		
		guard let prism = childNodes.first else {
			debugPrint("Prism root node »\(self.name ?? "---")« contains no child nodes.")
			return
		}

		guard years.count > year else {
			self.removeFromParentNode()
			return
		}
		
		if policyToggleAtFixedYear, let previousPolicy = previousClimatePolicy {
			let newValue = yearValue(year)
			let oldValue = yearValue(year, climatePolicy: previousPolicy)
			let newAbove = newValue > threshold
			let oldAbove = oldValue > threshold
			if abs(newValue - oldValue) <= Prism.policyValueEpsilon && newAbove == oldAbove {
				#if DEBUG
				if ClimatePolicyPerf.isPolicyUpdateActive {
					ClimatePolicyPerf.prismCounters.skippedUnchanged += 1
				}
				#endif
				return
			}
		}
		
		let value = yearValue(year)
		let aboveThreshold = value > threshold
		
		if !aboveThreshold && !visible && !forceResize && !policyToggleAtFixedYear {
			#if DEBUG
			if ClimatePolicyPerf.isPolicyUpdateActive {
				ClimatePolicyPerf.prismCounters.earlyReturn += 1
			}
			#endif
			return
		}
		
		let wasVisible = visible
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
		if wasVisible != visible {
			#if DEBUG
			if ClimatePolicyPerf.isPolicyUpdateActive {
				ClimatePolicyPerf.prismCounters.visibilityChange += 1
			}
			#endif
		}
		
		if policyToggleAtFixedYear && aboveThreshold && parent == nil {
			gridContainer.addChildNode(self)
			#if DEBUG
			if ClimatePolicyPerf.isPolicyUpdateActive {
				ClimatePolicyPerf.prismCounters.attachToGrid += 1
			}
			#endif
		}

		let height = value * heightFactor
		let width = widthSocket + value * widthFactor
		let newScale = SCNVector3(width, height, width) * scaleCorrection
		let newY = baseRadius + 0.5 * height
		let geometryChanged = !Prism.vectorNear(prism.scale, newScale, epsilon: Prism.geometryEpsilon)
			|| abs(prism.position.y - newY) > Prism.geometryEpsilon
		
		if geometryChanged {
			prism.scale = newScale
			prism.position.y = newY
			#if DEBUG
			if ClimatePolicyPerf.isPolicyUpdateActive {
				ClimatePolicyPerf.prismCounters.geometryUpdate += 1
			}
			#endif
		} else {
			#if DEBUG
			if ClimatePolicyPerf.isPolicyUpdateActive {
				ClimatePolicyPerf.prismCounters.geometrySkippedRedundant += 1
			}
			#endif
		}
		
		if tooltip != nil, geometryChanged {
			setTooltip(value: value, y: baseRadius * 1.03 + height * 1.005)
			#if DEBUG
			if ClimatePolicyPerf.isPolicyUpdateActive {
				ClimatePolicyPerf.prismCounters.tooltipUpdate += 1
			}
			#endif
		}
		
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


	/// Timeline year change: grid membership, visibility, and geometry in one pass.
	func applyTimelineYear(_ year: Int) {
		#if DEBUG
		if ClimatePolicyPerf.isPolicyUpdateActive {
			ClimatePolicyPerf.prismCounters.prismsVisited += 1
		}
		#endif
		
		guard years.count > year else {
			if parent != nil {
				removeFromParentNode()
				#if DEBUG
				if ClimatePolicyPerf.isPolicyUpdateActive {
					ClimatePolicyPerf.prismCounters.detachFromGrid += 1
				}
				#endif
			}
			return
		}
		
		let value = yearValue(year)
		let aboveThreshold = value > threshold
		
		if aboveThreshold {
			if parent == nil {
				gridContainer.addChildNode(self)
				#if DEBUG
				if ClimatePolicyPerf.isPolicyUpdateActive {
					ClimatePolicyPerf.prismCounters.attachToGrid += 1
				}
				#endif
			}
			if !visible { makeVisible() }
		} else {
			if visible { makeInvisible() }
			if parent != nil {
				removeFromParentNode()
				#if DEBUG
				if ClimatePolicyPerf.isPolicyUpdateActive {
					ClimatePolicyPerf.prismCounters.detachFromGrid += 1
				}
				#endif
			}
			#if DEBUG
			if ClimatePolicyPerf.isPolicyUpdateActive {
				ClimatePolicyPerf.prismCounters.earlyReturn += 1
			}
			#endif
			return
		}
		
		setYear(year, forceResize: false, policyToggleAtFixedYear: false, previousClimatePolicy: nil)
	}
	
	func addToContainer(for year: Int) {
		if yearValue(year) > threshold && self.parent == nil {
			gridContainer.addChildNode(self)
			#if DEBUG
			if ClimatePolicyPerf.isPolicyUpdateActive {
				ClimatePolicyPerf.prismCounters.attachToGrid += 1
			}
			#endif
		}
	}
	
	func removeFromContainer(for year: Int) {
		if yearValue(year) <= threshold && self.parent != nil {
			self.removeFromParentNode()
			#if DEBUG
			if ClimatePolicyPerf.isPolicyUpdateActive {
				ClimatePolicyPerf.prismCounters.detachFromGrid += 1
			}
			#endif
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

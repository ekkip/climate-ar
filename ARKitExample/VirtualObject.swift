/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Wrapper SceneKit node for virtual objects placed into the AR scene.
*/

import Foundation
import SceneKit
import ARKit

class VirtualObject: SCNNode {
	
	var modelName: String = ""
	var fileExtension: String = ""
	var thumbImage: UIImage! = UIImage()
	var title: String = ""
	var modelLoaded: Bool = false
	var modelScene: SCNScene?
	
	var viewController: ViewController?
	
	override init() {
		super.init()
		self.name = "Virtual object root node"
	}
	
	init(modelName: String, fileExtension: String, thumbImageFilename: String? = nil, title: String? = nil) {
		super.init()
		self.name = "Virtual object root node"
		self.modelName = modelName
		self.fileExtension = fileExtension
		if let thumbImageFilename = thumbImageFilename {
			self.thumbImage = UIImage(named: thumbImageFilename)
		}
		
//		if let image = UIImage(named: thumbImageFilename) {
//			self.thumbImage = image
//		}
		if let title = title {
			self.title = title
		}
	}
	
	required init?(coder aDecoder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
	
	func loadModel() {
		guard let virtualObjectScene = SCNScene(named: "\(modelName).\(fileExtension)", inDirectory: "Models.scnassets/\(modelName)") else {
			print("Could not import Models.scnassets/\(modelName)/\(modelName).\(fileExtension)")
			return
		}
		modelScene = virtualObjectScene
		
		let wrapperNode = SCNNode()
		
		for child in virtualObjectScene.rootNode.childNodes {
			// child.geometry?.firstMaterial?.lightingModel = .physicallyBased
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
			wrapperNode.addChildNode(child)
		}
		self.addChildNode(wrapperNode)
		
		modelLoaded = true
	}
	
	func unloadModel() {
		for child in self.childNodes {
			child.removeFromParentNode()
		}
		
		modelLoaded = false
	}
	
	func translateBasedOnScreenPos(_ pos: CGPoint, instantly: Bool, infinitePlane: Bool) {
		
		guard let controller = viewController else {
			return
		}
		
		let result = controller.worldPositionFromScreenPosition(pos, objectPos: self.position, infinitePlane: infinitePlane)

		controller.moveVirtualObjectToPosition(result.position, instantly, !result.hitAPlane)
	}
	
	func translateBasedOnWorldPosition(_ pos: SCNVector3, instantly: Bool, infinitePlane: Bool) {

		guard let controller = viewController else {
			return
		}
		
		controller.moveVirtualObjectToPosition(pos, instantly, false)
	}
}

extension VirtualObject {
	
	static func isNodePartOfVirtualObject(_ node: SCNNode) -> Bool {
		debugPrint("\(#function) – \(node.name ?? "---")")
		if node.name == "Virtual object root node" {
			return true
		}
		
		if node.parent != nil {
			debugPrint("\(#function) – \(node.name ?? "---")")
			return isNodePartOfVirtualObject(node.parent!)
		}
		
		return false
	}
	
	static func isNodePartOfGlobePreview(_ node: SCNNode) -> Bool {
		if node.name == "Globe preview" {
			return true
		}
		
		if let parent = node.parent {
			return isNodePartOfGlobePreview(parent)
		}
		
		return false
	}
	
	static func globePreview(from childNode: SCNNode) -> SCNNode? {
		if childNode.name == "Globe preview" {
			return childNode
		}
		
		if let parent = childNode.parent {
			return globePreview(from: parent)
		}
		
		return nil
	}
	
//	static let availableObjects: [VirtualObject] = [
//		Globe()
//	]
}

// MARK: - Protocols for Virtual Objects

protocol ReactsToScale {
	func reactToScale()
}

extension SCNNode {
	
	func reactsToScale() -> ReactsToScale? {
		if let canReact = self as? ReactsToScale {
			return canReact
		}
		
		if parent != nil {
			return parent!.reactsToScale()
		}
		
		return nil
	}
}

/*
See LICENSE folder for this sample's licensing information.

Abstract:
SceneKit-only preview without ARSession (Simulator and iOS app on Mac).
*/

import SceneKit
import UIKit

enum NonARPreview {
	/// Matches standing eye height; ground is at y = 0 for scale math.
	static let cameraHeightAboveGround: Float = 1.5
	static let globeDistanceFromCamera: Float = 2.0
	/// Same factor as `setNewVirtualObjectPosition` (`deltaHeight * 0.75`).
	static let globeScaleHeightFactor: Float = 0.75

	static let sceneBackgroundColor = UIColor(red: 0.04, green: 0.10, blue: 0.22, alpha: 1.0)

	// Use Sanssouci on-site background image for App Store imagery
	// (Dark blue background colour if usesBGImage set to false)
	static let usesBGImage = false
	static let backgroundImageName = "Sanssouci nur BG"

	static let lightingEnvironmentIntensity: CGFloat = 5
	static let directionalLightIntensity: CGFloat = 320
}

extension ViewController {

	private enum NonARPreviewScene {
		static let cameraNodeName = "NonARPreviewCamera"
		static let lightNodeName = "NonARPreviewLight"
	}

	func configureNonARPreviewSceneIfNeeded() {
		if sceneView.scene == nil {
			sceneView.scene = SCNScene()
		}

		applyNonARPreviewBackground()
		sceneView.isPlaying = true
		sceneView.rendersContinuously = true
		ensureNonARPreviewCamera()
		applyNonARPreviewLighting()
	}

	func applyNonARPreviewBackground() {
		if NonARPreview.usesBGImage, let image = UIImage(named: NonARPreview.backgroundImageName) {
			sceneView.scene.background.contents = image
			sceneView.backgroundColor = NonARPreview.sceneBackgroundColor
		} else {
			sceneView.scene.background.contents = NonARPreview.sceneBackgroundColor
			sceneView.backgroundColor = NonARPreview.sceneBackgroundColor
		}
	}

	func applyNonARPreviewLighting() {
		sceneView.autoenablesDefaultLighting = false
		sceneView.rendersContinuously = true
		enableEnvironmentMapWithIntensity(NonARPreview.lightingEnvironmentIntensity)
		markEnvironmentIntensityApplied(NonARPreview.lightingEnvironmentIntensity)

		if let lightNode = sceneView.scene.rootNode.childNode(withName: NonARPreviewScene.lightNodeName, recursively: false) {
			lightNode.light?.intensity = NonARPreview.directionalLightIntensity
		}
	}

	func ensureNonARPreviewCamera() {
		let scene = sceneView.scene ?? SCNScene()
		if sceneView.scene == nil {
			sceneView.scene = scene
		}

		let cameraNode: SCNNode
		if let existing = scene.rootNode.childNode(withName: NonARPreviewScene.cameraNodeName, recursively: false) {
			cameraNode = existing
		} else {
			cameraNode = SCNNode()
			cameraNode.name = NonARPreviewScene.cameraNodeName
			cameraNode.camera = SCNCamera()
			scene.rootNode.addChildNode(cameraNode)

			if scene.rootNode.childNode(withName: NonARPreviewScene.lightNodeName, recursively: false) == nil {
				let lightNode = SCNNode()
				lightNode.name = NonARPreviewScene.lightNodeName
				lightNode.light = SCNLight()
				lightNode.light?.type = .directional
				lightNode.light?.intensity = NonARPreview.directionalLightIntensity
				lightNode.eulerAngles = SCNVector3(-0.6, 0.35, 0)
				scene.rootNode.addChildNode(lightNode)
			}
		}

		sceneView.pointOfView = cameraNode
		resetNonARPreviewCameraPose()

		if let camera = cameraNode.camera {
			camera.wantsHDR = false
			camera.wantsExposureAdaptation = false
			camera.exposureOffset = 0
			camera.minimumExposure = 0
		}
	}

	func resetNonARPreviewCameraPose() {
		guard let cameraNode = sceneView.pointOfView else { return }
		cameraNode.constraints = []
		cameraNode.position = SCNVector3(0, NonARPreview.cameraHeightAboveGround, 0)
		cameraNode.eulerAngles = SCNVector3Zero
	}

	func startNonARPreview() {
		configureNonARPreviewSceneIfNeeded()
		textManager.cancelAllScheduledMessages()
		tryNonARPreviewPlacementIfReady()
	}

	func tryNonARPreviewPlacementIfReady() {
		guard globeState != .placed else { return }
		guard globe.modelLoaded else { return }
		autoPlaceGlobeForNonARPreview()
	}

	private func nonARPreviewGlobePositionOnFloor() -> SCNVector3 {
		SCNVector3(0, 0, -NonARPreview.globeDistanceFromCamera)
	}

	private func nonARGlobeVisualCenterWorldPosition() -> SCNVector3 {
		guard let core = globe.coreGlobe else {
			return globe.presentation.worldPosition
		}
		let box = core.boundingBox
		let localCenter = SCNVector3(
			(box.min.x + box.max.x) * 0.5,
			(box.min.y + box.max.y) * 0.5,
			(box.min.z + box.max.z) * 0.5
		)
		return core.convertPosition(localCenter, to: nil)
	}

	private func frameNonARPreviewCameraOnGlobe() {
		guard let camera = sceneView.pointOfView else { return }
		resetNonARPreviewCameraPose()
		camera.look(
			at: nonARGlobeVisualCenterWorldPosition(),
			up: SCNVector3(0, 1, 0),
			localFront: SCNVector3(0, 0, -1)
		)
	}

	func autoPlaceGlobeForNonARPreview() {
		guard globeState != .placed else { return }
		guard globe.modelLoaded else { return }

		ensureNonARPreviewCamera()

		recentVirtualObjectDistances.removeAll()

		let scale = NonARPreview.cameraHeightAboveGround * NonARPreview.globeScaleHeightFactor
		globe.scale = SCNVector3(scale, scale, scale)

		focusSquare?.removeFromParentNode()
		focusSquare?.previewGlobe.removeFromParentNode()

		if globe.parent == nil {
			sceneView.scene.rootNode.addChildNode(globe)
		}

		globe.position = nonARPreviewGlobePositionOnFloor()
		frameNonARPreviewCameraOnGlobe()
		applyNonARPreviewLighting()

		finalizeGlobePlacementUI()
	}
}

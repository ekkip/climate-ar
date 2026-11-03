/*
See LICENSE folder for this sample's licensing information.

Abstract:
SceneKit-only preview on the iOS Simulator (no ARSession).
*/

import SceneKit
import UIKit

extension ViewController {

	private enum NonARPreviewScene {
		static let cameraNodeName = "NonARPreviewCamera"
		static let lightNodeName = "NonARPreviewLight"
	}

	func configureNonARPreviewSceneIfNeeded() {
		guard AppRuntime.usesNonARPreview else { return }

		if sceneView.scene == nil {
			sceneView.scene = SCNScene()
		}

		sceneView.scene.background.contents = NonARPreview.sceneBackgroundColor
		sceneView.backgroundColor = NonARPreview.sceneBackgroundColor
		sceneView.isPlaying = true
		sceneView.rendersContinuously = true
		ensureNonARPreviewCamera()
		applyNonARPreviewLighting()
	}

	func applyNonARPreviewLighting() {
		guard AppRuntime.usesNonARPreview else { return }

		// Default SceneKit lighting stacks with the IBL and reads brighter than on device AR.
		sceneView.autoenablesDefaultLighting = false
		sceneView.rendersContinuously = true
		enableEnvironmentMapWithIntensity(NonARPreview.lightingEnvironmentIntensity)
		markEnvironmentIntensityApplied(NonARPreview.lightingEnvironmentIntensity)

		if let lightNode = sceneView.scene.rootNode.childNode(withName: NonARPreviewScene.lightNodeName, recursively: false) {
			lightNode.light?.intensity = NonARPreview.directionalLightIntensity
		}
	}

	/// ARSCNView does not install a rendering camera until an AR session runs; create one for SceneKit-only preview.
	func ensureNonARPreviewCamera() {
		guard AppRuntime.usesNonARPreview else { return }

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
		guard AppRuntime.usesNonARPreview else { return }

		configureNonARPreviewSceneIfNeeded()
		textManager.cancelAllScheduledMessages()
		tryNonARPreviewPlacementIfReady()
	}

	func tryNonARPreviewPlacementIfReady() {
		guard AppRuntime.usesNonARPreview, globeState != .placed else { return }
		guard globe.modelLoaded else { return }
		autoPlaceGlobeForNonARPreview()
	}

	/// Globe on the floor, 2 m in front of the world origin (same scale rule as AR at 1.5 m eye height).
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

	/// Fixed eye position; rotate only to center the globe mesh in the view.
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
		guard AppRuntime.usesNonARPreview, globeState != .placed else { return }
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

/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Main view controller for the AR experience.
*/

import ARKit
import Foundation
import SceneKit
import UIKit
import Photos
//import StyledString
import SwiftyAttributes

class ViewController: UIViewController, ARSessionDelegate, ARSCNViewDelegate, UIPopoverPresentationControllerDelegate, /*VirtualObjectSelectionViewControllerDelegate,*/ UIScrollViewDelegate {
	
	let globe = Globe()
	
	enum GlobeState {
		case loading, loaded, placed
	}
	
	
    // MARK: - Main Setup & View Controller methods
    override func viewDidLoad() {
        super.viewDidLoad()

        Setting.registerDefaults()
        setupScene()
        setupDebug()
        setupUIControls()
//		setupFocusSquare()
		updateSettings()
		resetVirtualObject()
		
		debugPrint("Showing introduction on startup: \(UserDefaults.standard.bool(for: .showIntroductionOnStartup))")
		
//		debugPrint("Font families available: \(UIFont.familyNames)")
		for fontName in UIFont.fontNames(forFamilyName: "Rubik") {
			debugPrint("Rubik font: »\(fontName)«")
		}
		
		setupMenu()
    }

	override func viewWillAppear(_ animated: Bool) {
		super.viewWillAppear(animated)

		dismissIntroduction()
	}
	
	
	override func viewDidAppear(_ animated: Bool) {
		super.viewDidAppear(animated)

		setupGlobe()
		
		autoplayButton.layer.borderWidth = 2
		autoplayButton.layer.borderColor = UIColor.white.cgColor
		autoplayButton.layer.cornerRadius = autoplayButton.frame.size.width / 2

		// Prevent the screen from being dimmed after a while.
		UIApplication.shared.isIdleTimerDisabled = true
		
		// Start the ARSession.
		restartPlaneDetection()
		
		setShowIntroductionOnStartupButton()
		if UserDefaults.standard.bool(for: .showIntroductionOnStartup) {
			presentIntroduction()
		}
		
	}
	
	override func viewWillDisappear(_ animated: Bool) {
		super.viewWillDisappear(animated)
		session.pause()
	}
	
	
    // MARK: - ARKit / ARSCNView
    let session = ARSession()
	var sessionConfig: ARConfiguration = ARWorldTrackingConfiguration()
	var use3DOFTracking = false {
		didSet {
			if use3DOFTracking {
				sessionConfig = AROrientationTrackingConfiguration()
			}
			sessionConfig.isLightEstimationEnabled = true //UserDefaults.standard.bool(for: .ambientLightEstimation)
			debugPrint("Light estimation enabled: \(sessionConfig.isLightEstimationEnabled)")
			session.run(sessionConfig)
		}
	}
	var use3DOFTrackingFallback = false
    @IBOutlet var sceneView: ARSCNView!
	var screenCenter: CGPoint?
    
    func setupScene() {
		
		session.delegate = self
		
        // set up sceneView
        sceneView.delegate = self
        sceneView.session = session
		sceneView.insetsLayoutMarginsFromSafeArea = false
		sceneView.antialiasingMode = .multisampling4X
		sceneView.autoenablesDefaultLighting = false
		sceneView.automaticallyUpdatesLighting = false
		
		sceneView.preferredFramesPerSecond = 60
		sceneView.contentScaleFactor = 1.3
		sceneView.showsStatistics = false
		
		debugPrint("view.frame: \(view.frame)")
		debugPrint("sceneView.frame: \(sceneView.frame)")

		enableEnvironmentMapWithIntensity(25.0)
		
		DispatchQueue.main.async {
//			self.screenCenter = self.sceneView.bounds.mid
			self.screenCenter = CGPoint(x: self.sceneView.bounds.midX, y: self.sceneView.bounds.maxY * 0.75)
		}
		
		if let camera = sceneView.pointOfView?.camera {
			camera.wantsHDR = true
			camera.wantsExposureAdaptation = true
			camera.exposureOffset = -1
			camera.minimumExposure = -1
		}
    }
	
	func enableEnvironmentMapWithIntensity(_ intensity: CGFloat) {
//		debugPrint("\(#function) – overwriting existing intensity \(sceneView.scene.lightingEnvironment.intensity) with \(intensity)")
		
//		return
		
		if sceneView.scene.lightingEnvironment.contents == nil {
			debugPrint("lightingEnvironment.contents is nil!")
			if let environmentMap = UIImage(named: "Models.scnassets/sharedImages/environment_blur.exr") {
//			if let environmentMap = UIImage(named: "Models.scnassets/sharedImages/environment.jpg") {
				debugPrint("Applying environment.jpg …")
				sceneView.scene.lightingEnvironment.contents = environmentMap
			}
		}
		sceneView.scene.lightingEnvironment.intensity = intensity
//		debugPrint("Successfully overwrote intensity: \(sceneView.scene.lightingEnvironment.intensity)")
	}
	
	// MARK: - ARSessionDelegate
	
	var initialCameraPosition: SCNVector3?
	
	func session(_ session: ARSession, didUpdate frame: ARFrame) {
		
		if
//			let globe = virtualObject as? Globe,
			let cameraTransform = session.currentFrame?.camera.transform
		{
			
			let cameraPosFromTransform = SCNVector3.positionFromTransform(cameraTransform)
			
			let savedCameraPosition = initialCameraPosition ?? cameraPosFromTransform
			if initialCameraPosition == nil {
				initialCameraPosition = cameraPosFromTransform
			}
			
			// Calculate the angle (Y-axis-ignorant 2D) between
			// the vector from the globe center to the edge median of the player's side and
			// the vector from the globe center to the camera position
			
			let cameraPos = cameraPosFromTransform - savedCameraPosition
			let globePos = globe.position
			let globeYaw = globe.eulerAngles.y
			
			let globeCameraAngle = atan2f(cameraPos.x - globePos.x, cameraPos.z-globePos.z)
			
			var cameraPositionDeviation = globeCameraAngle - globeYaw
			while cameraPositionDeviation > Float.pi { cameraPositionDeviation -= 2*Float.pi }
			while cameraPositionDeviation < -Float.pi { cameraPositionDeviation += 2*Float.pi }
			
			globe.adjustTooltipAligments(viewingAngle: cameraPositionDeviation, cameraDistance: (globe.position-cameraPos).length())
		}
	}
	
    // MARK: - ARSCNViewDelegate
	let ambientIntensityQuotient: CGFloat = 80
	var lastLightIntensityEstimate: CGFloat = 0
	func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
		
//		debugPrint("Globe is in scene: \(globe.parent != nil)")
//		sceneView.scene.rootNode.printNodeHierarchy()
		
//		var timestamp = print(intervalSince: Date(), string: "Flag0")
		refreshFeaturePoints()
		
		DispatchQueue.main.async {
//			var timestamp = print(intervalSince: Date(), string: "Flag1")
			self.updateFocusSquare()
//			timestamp = print(intervalSince: timestamp, string: "Flag2")
			self.hitTestVisualization?.render()
			
//			// If light estimation is enabled, update the intensity of the model's lights and the environment map
//			if let lightEstimate = self.session.currentFrame?.lightEstimate {
//				if abs(lightEstimate.ambientIntensity - self.lastLightIntensityEstimate) > 50 {
//					debugPrint("lightEstimate.ambientIntensity: \(lightEstimate.ambientIntensity)")
//					self.lastLightIntensityEstimate = lightEstimate.ambientIntensity
//				}
//				self.enableEnvironmentMapWithIntensity(lightEstimate.ambientIntensity / self.ambientIntensityQuotient)
//			} else {
//				debugPrint("Frame has no lightEstimate -> applying \(1000/self.ambientIntensityQuotient) …")
//				self.enableEnvironmentMapWithIntensity(1000/self.ambientIntensityQuotient)
//			}
			
//			timestamp = print(intervalSince: timestamp, string: "Flag3")
			if let lightEstimate = self.session.currentFrame?.lightEstimate {
				self.enableEnvironmentMapWithIntensity(lightEstimate.ambientIntensity / self.ambientIntensityQuotient)
			} else {
				self.enableEnvironmentMapWithIntensity(10)
			}
//			timestamp = print(intervalSince: timestamp, string: "Flag4")
		}
	}
	
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        DispatchQueue.main.async {
            if let planeAnchor = anchor as? ARPlaneAnchor {
				self.addPlane(node: node, anchor: planeAnchor)
                self.checkIfObjectShouldMoveOntoPlane(anchor: planeAnchor)
            }
        }
    }
	
    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        DispatchQueue.main.async {
            if let planeAnchor = anchor as? ARPlaneAnchor {
                self.updatePlane(anchor: planeAnchor)
                self.checkIfObjectShouldMoveOntoPlane(anchor: planeAnchor)
            }
        }
    }
	
    func renderer(_ renderer: SCNSceneRenderer, didRemove node: SCNNode, for anchor: ARAnchor) {
        DispatchQueue.main.async {
            if let planeAnchor = anchor as? ARPlaneAnchor {
                self.removePlane(anchor: planeAnchor)
            }
        }
    }
	
	var trackingFallbackTimer: Timer?


	
	func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {

		textManager.showTrackingQualityInfo(for: camera.trackingState, autoHide: !self.showDebugVisuals)

        switch camera.trackingState {
        case .notAvailable:
            textManager.escalateFeedback(for: camera.trackingState, inSeconds: 5.0)
        case .limited:
            if use3DOFTrackingFallback {
                // After 10 seconds of limited quality, fall back to 3DOF mode.
                trackingFallbackTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: false, block: { _ in
                    self.use3DOFTracking = true
                    self.trackingFallbackTimer?.invalidate()
                    self.trackingFallbackTimer = nil
                })
            } else {
                textManager.escalateFeedback(for: camera.trackingState, inSeconds: 10.0)
            }
        case .normal:
            textManager.cancelScheduledMessage(forType: .trackingStateEscalation)
            if use3DOFTrackingFallback && trackingFallbackTimer != nil {
                trackingFallbackTimer!.invalidate()
                trackingFallbackTimer = nil
            }
        }
	}
	
    func session(_ session: ARSession, didFailWithError error: Error) {

        guard let arError = error as? ARError else { return }

        let nsError = error as NSError
		var sessionErrorMsg = "\(nsError.localizedDescription) \(nsError.localizedFailureReason ?? "")"
		if let recoveryOptions = nsError.localizedRecoveryOptions {
			for option in recoveryOptions {
				sessionErrorMsg.append("\(option).")
			}
		}

        let isRecoverable = (arError.code == .worldTrackingFailed)
		if isRecoverable {
			sessionErrorMsg += "\nYou can try resetting the session or quit the application."
		} else {
			sessionErrorMsg += "\nThis is an unrecoverable error that requires to quit the application."
		}
		
		displayErrorMessage(title: "We're sorry!", message: sessionErrorMsg, allowRestart: isRecoverable)
	}
	
	func sessionWasInterrupted(_ session: ARSession) {
		textManager.blurBackground()
		textManager.showAlert(title: "Session Interrupted", message: "The session will be reset after the interruption has ended.")
	}
		
	func sessionInterruptionEnded(_ session: ARSession) {
		textManager.unblurBackground()
		session.run(sessionConfig, options: [.resetTracking, .removeExistingAnchors])
		restartExperience(self)
//		textManager.showMessage("RESETTING SESSION")
	}
	
    // MARK: - Ambient Light Estimation
	
	func toggleAmbientLightEstimation(_ enabled: Bool) {
		
        if enabled {
			if !sessionConfig.isLightEstimationEnabled {
				// turn on light estimation
				sessionConfig.isLightEstimationEnabled = true
				session.run(sessionConfig)
			}
        } else {
			if sessionConfig.isLightEstimationEnabled {
				// turn off light estimation
				sessionConfig.isLightEstimationEnabled = false
				session.run(sessionConfig)
			}
        }
    }

    // MARK: - Gesture Recognizers
	
	var currentGesture: Gesture?
	
	override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
//		guard let object = virtualObject else {
//			return
//		}
		
		if currentGesture == nil {
			currentGesture = Gesture.startGestureFromTouches(touches, self.sceneView, globe)
		} else {
			currentGesture = currentGesture!.updateGestureFromTouches(touches, .touchBegan)
		}
		
		displayVirtualObjectTransform()
	}
	
	override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
		if virtualObject == nil {
			return
		}
		currentGesture = currentGesture?.updateGestureFromTouches(touches, .touchMoved)
		displayVirtualObjectTransform()
	}
	
	override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
//		if virtualObject == nil {
////			chooseObject(addObjectButton)
//			loadVirtualObject(at: 0)
//			return
//		}

		if globeState == .loaded {
			placeGlobe()
		}
		
		currentGesture = currentGesture?.updateGestureFromTouches(touches, .touchEnded)
	}
	
	override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
//		if virtualObject == nil {
//			return
//		}
		currentGesture = currentGesture?.updateGestureFromTouches(touches, .touchCancelled)
	}
	
	// MARK: - Virtual Object Manipulation
	
	func displayVirtualObjectTransform() {
		
		guard /*let object = virtualObject,*/ let cameraTransform = session.currentFrame?.camera.transform else {
			return
		}
		
		// Output the current translation, rotation & scale of the globe as text.
		
		let cameraPos = SCNVector3.positionFromTransform(cameraTransform)
		let vectorToCamera = cameraPos - globe.position
		
		let distanceToUser = vectorToCamera.length()
		
		var angleDegrees = Int(((globe.eulerAngles.y) * 180) / Float.pi) % 360
		if angleDegrees < 0 {
			angleDegrees += 360
		}
		
		let distance = String(format: "%.2f", distanceToUser)
		let scale = String(format: "%.2f", globe.scale.x)
		textManager.showDebugMessage("Distance: \(distance) m\nRotation: \(angleDegrees)°\nScale: \(scale)x")
	}
	
	func moveVirtualObjectToPosition(_ pos: SCNVector3?, _ instantly: Bool, _ filterPosition: Bool) {
		
		guard let newPosition = pos else {
			textManager.showMessage("CANNOT PLACE OBJECT\nTry moving left or right.")
			// Reset the content selection in the menu only if the content has not yet been initially placed.
			if virtualObject == nil {
				debugPrint("FLAG 1")
				resetVirtualObject()
			}
			return
		}
		
		if instantly {
			setNewVirtualObjectPosition(newPosition)
		} else {
			updateVirtualObjectPosition(newPosition, filterPosition)
		}
	}
	
	var dragOnInfinitePlanesEnabled = false
	
	func worldPositionFromScreenPosition(_ position: CGPoint,
	                                     objectPos: SCNVector3?,
	                                     infinitePlane: Bool = false) -> (position: SCNVector3?, planeAnchor: ARPlaneAnchor?, hitAPlane: Bool) {
		
		// -------------------------------------------------------------------------------
		// 1. Always do a hit test against exisiting plane anchors first.
		//    (If any such anchors exist & only within their extents.)
		
		let planeHitTestResults = sceneView.hitTest(position, types: .existingPlaneUsingExtent)
		if let result = planeHitTestResults.first {
			
			let planeHitTestPosition = SCNVector3.positionFromTransform(result.worldTransform)
			let planeAnchor = result.anchor
			
			// Return immediately - this is the best possible outcome.
			return (planeHitTestPosition, planeAnchor as? ARPlaneAnchor, true)
		}
		
		// -------------------------------------------------------------------------------
		// 2. Collect more information about the environment by hit testing against
		//    the feature point cloud, but do not return the result yet.
		
		var featureHitTestPosition: SCNVector3?
		var highQualityFeatureHitTestResult = false
		
		let highQualityfeatureHitTestResults = sceneView.hitTestWithFeatures(position, coneOpeningAngleInDegrees: 18, minDistance: 0.2, maxDistance: 2.0)
		
		if !highQualityfeatureHitTestResults.isEmpty {
			let result = highQualityfeatureHitTestResults[0]
			featureHitTestPosition = result.position
			highQualityFeatureHitTestResult = true
		}
		
		// -------------------------------------------------------------------------------
		// 3. If desired or necessary (no good feature hit test result): Hit test
		//    against an infinite, horizontal plane (ignoring the real world).
		
		if (infinitePlane && dragOnInfinitePlanesEnabled) || !highQualityFeatureHitTestResult {
			
			let pointOnPlane = objectPos ?? SCNVector3Zero
			
			let pointOnInfinitePlane = sceneView.hitTestWithInfiniteHorizontalPlane(position, pointOnPlane)
			if pointOnInfinitePlane != nil {
				return (pointOnInfinitePlane, nil, true)
			}
		}
		
		// -------------------------------------------------------------------------------
		// 4. If available, return the result of the hit test against high quality
		//    features if the hit tests against infinite planes were skipped or no
		//    infinite plane was hit.
		
		if highQualityFeatureHitTestResult {
			return (featureHitTestPosition, nil, false)
		}
		
		// -------------------------------------------------------------------------------
		// 5. As a last resort, perform a second, unfiltered hit test against features.
		//    If there are no features in the scene, the result returned here will be nil.
		
		let unfilteredFeatureHitTestResults = sceneView.hitTestWithFeatures(position)
		if !unfilteredFeatureHitTestResults.isEmpty {
			let result = unfilteredFeatureHitTestResults[0]
			return (result.position, nil, false)
		}
		
		return (nil, nil, false)
	}
	
	// Use average of recent virtual object distances to avoid rapid changes in object scale.
	var recentVirtualObjectDistances = [CGFloat]()
	
    func setNewVirtualObjectPosition(_ pos: SCNVector3) {
	
		guard /*let object = virtualObject,*/ let cameraTransform = session.currentFrame?.camera.transform else {
			return
		}
		
		debugPrint("\(#function) – new position: \(pos)")
		
		recentVirtualObjectDistances.removeAll()
		
		let cameraWorldPos = SCNVector3.positionFromTransform(cameraTransform)
		var cameraToPosition = pos - cameraWorldPos
		
		// Limit the distance of the globe from the camera to a maximum of 10 meters.
		cameraToPosition.setMaximumLength(10)

		let deltaHeight = cameraWorldPos.y - pos.y

		globe.scale = SCNVector3(deltaHeight, deltaHeight, deltaHeight) * 0.75
		
		globe.position = cameraWorldPos + cameraToPosition
		
//		if globe.parent == nil {
//			sceneView.scene.rootNode.addChildNode(globe)
////			debugPrint("Looking up globe's modelScene …")
////			if let lightingEnvironment = object.modelScene?.lightingEnvironment {
////				debugPrint("Setting scene lightingEnvironment intensity to modelScene's \(lightingEnvironment.intensity)")
////				sceneView.scene.lightingEnvironment.contents = lightingEnvironment.contents
////				sceneView.scene.lightingEnvironment.intensity = lightingEnvironment.intensity
////			}
////			else {
////				debugPrint("Globe's modelScene not found!")
////			}
//		}
    }

	func resetVirtualObject() {
		
		initialCameraPosition = nil
		
//		virtualObject?.unloadModel()
//		virtualObject?.removeFromParentNode()
//		virtualObject = nil
//
//		addObjectButton.setImage(#imageLiteral(resourceName: "add"), for: [])
//		addObjectButton.setImage(#imageLiteral(resourceName: "addPressed"), for: [.highlighted])
//
//		// Reset selected object id for row highlighting in object selection view controller.
//		UserDefaults.standard.set(-1, for: .selectedObjectID)
		
//		for childNode in self.sceneView.scene.rootNode.childNodes {
//			childNode.removeFromParentNode()
//		}
		
		resetGlobe()
		
	}
	
	func updateVirtualObjectPosition(_ pos: SCNVector3, _ filterPosition: Bool) {
//		guard let object = virtualObject else {
//			return
//		}
		
		guard let cameraTransform = session.currentFrame?.camera.transform else {
			return
		}
		
		let cameraWorldPos = SCNVector3.positionFromTransform(cameraTransform)
		var cameraToPosition = pos - cameraWorldPos
		
		// Limit the distance of the globe from the camera to a maximum of 10 meters.
		cameraToPosition.setMaximumLength(10)
		
		// Compute the average distance of the globe from the camera over the last ten
		// updates. If filterPosition is true, compute a new position for the globe
		// with this average. Notice that the distance is applied to the vector from
		// the camera to the content, so it only affects the percieved distance of the
		// globe - the averaging does _not_ make the content "lag".
		let hitTestResultDistance = CGFloat(cameraToPosition.length())

		recentVirtualObjectDistances.append(hitTestResultDistance)
		recentVirtualObjectDistances.keepLast(10)
		
		if filterPosition {
			let averageDistance = recentVirtualObjectDistances.average!
			
			cameraToPosition.setLength(Float(averageDistance))
			let averagedDistancePos = cameraWorldPos + cameraToPosition

			globe.position = averagedDistancePos
		} else {
			globe.position = cameraWorldPos + cameraToPosition
		}
    }
	
	func checkIfObjectShouldMoveOntoPlane(anchor: ARPlaneAnchor) {
		guard /*let object = virtualObject,*/ let planeAnchorNode = sceneView.node(for: anchor) else {
			return
		}
		
		// Get the globe's position in the plane's coordinate system.
		let objectPos = planeAnchorNode.convertPosition(globe.position, from: globe.parent)
		
		if objectPos.y == 0 {
			return; // The globe is already on the plane - nothing to do here.
		}
		
		// Add 10% tolerance to the corners of the plane.
		let tolerance: Float = 0.1
		
		let minX: Float = anchor.center.x - anchor.extent.x / 2 - anchor.extent.x * tolerance
		let maxX: Float = anchor.center.x + anchor.extent.x / 2 + anchor.extent.x * tolerance
		let minZ: Float = anchor.center.z - anchor.extent.z / 2 - anchor.extent.z * tolerance
		let maxZ: Float = anchor.center.z + anchor.extent.z / 2 + anchor.extent.z * tolerance
		
		if objectPos.x < minX || objectPos.x > maxX || objectPos.z < minZ || objectPos.z > maxZ {
			return
		}
		
		// Drop the globe onto the plane if it is near it.
		let verticalAllowance: Float = 0.03
		if objectPos.y > -verticalAllowance && objectPos.y < verticalAllowance {
			textManager.showDebugMessage("OBJECT MOVED\nSurface detected nearby")
			
			SCNTransaction.begin()
			SCNTransaction.animationDuration = 0.5
			SCNTransaction.animationTimingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.easeInEaseOut)
			globe.position.y = anchor.transform.columns.3.y
			SCNTransaction.commit()
		}
	}
	
    // MARK: - Virtual Object Loading
	
	var virtualObject: VirtualObject?
	var isLoadingObject: Bool = false {
		didSet {
			DispatchQueue.main.async {
//				self.settingsButton.isEnabled = !self.isLoadingObject
//				self.addObjectButton.isEnabled = !self.isLoadingObject
				self.screenshotButton.isEnabled = !self.isLoadingObject
				self.restartExperienceButton.isEnabled = !self.isLoadingObject
			}
		}
	}
	
//	@IBOutlet weak var addObjectButton: UIButton!
	
	func loadVirtualObject(at index: Int, placeObject: Bool = true) {
//		resetVirtualObject()
		
		debugPrint("\(#function)")
		
		// Show progress indicator
		let spinner = UIActivityIndicatorView()
		spinner.style = .whiteLarge
//		spinner.center = addObjectButton.center
		spinner.center = view.center
//		spinner.bounds.size = CGSize(width: button.bounds.width - 5, height: addObjectButton.bounds.height - 5)
//		addObjectButton.setImage(#imageLiteral(resourceName: "buttonring"), for: [])
		sceneView.addSubview(spinner)
		spinner.startAnimating()
		
		// Load the content asynchronously.
		DispatchQueue.global().async {
			self.isLoadingObject = true
//			let object = Globe()// VirtualObject.availableObjects[index]
			self.globe.viewController = self
			self.virtualObject = self.globe

//			debugPrint("Virtual object is globe: \(object is Globe)")
			debugPrint("ARCamera exists: \(self.session.currentFrame?.camera != nil)")
			
//			if let globe = object as? Globe, let camera = self.session.currentFrame?.camera {
//				globe.loadModel(camera: camera)
//			}
//			else {
				self.globe.loadModel()
//			}
			
			DispatchQueue.main.async {
				// Immediately place the object in 3D space.
				if let lastFocusSquarePos = self.focusSquare?.lastPosition, placeObject {
					self.setNewVirtualObjectPosition(lastFocusSquarePos)
				} else {
					self.setNewVirtualObjectPosition(SCNVector3Zero)
				}
				
				// Remove progress indicator
				spinner.removeFromSuperview()
				
				self.textManager.showMessage("TAP TO PLACE", autoHide: false)
				
				// Update the icon of the add object button
				self.isLoadingObject = false
				self.globeState = .loaded
				
				self.setupFocusSquare()
				
				self.checkIntroductionVisible("FLAG 1")
				
				var timerCounter = 2
				Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true, block: { (_) in
					self.checkIntroductionVisible("FLAG \(timerCounter)")
					timerCounter += 1
				}).fire()
			}
		}
    }
	
	
	// MARK: - Globe
	
	@IBOutlet weak var globeControlPanel: UIView!
	@IBOutlet weak var timeScrollView: UIScrollView!
	@IBOutlet weak var focusTimeScrollView: UIScrollView!
	@IBOutlet weak var autoplayButton: UIButton!
	@IBOutlet weak var climatePolicySimulationPanel: UIView!
	@IBOutlet weak var climatePolicySwitch: UISwitch!
	
	var globeState = GlobeState.loading
	var autoplayTimer: Timer? = nil {
		willSet { self.autoplayTimer?.invalidate() }
	}
//	var autoplay = false
	
//	func timeScrollViewLabel(offset: CGFloat, text: String, focus: Bool) {
//		let label = UILabel(frame: CGRect(x: offset, y: 4, width: 80, height: 28))
//		label.text = text
//		yearLabel.font = UIFont.rubikLight(size: 26)
//	}
	
	func setupGlobe() {
		globeState = .loading
		loadVirtualObject(at: 0, placeObject: false)
		
		let padding = self.timeScrollView.frame.size.width / 2 - 40
		var offset = padding
		var contentRect = CGRect.zero
		for i in 0...35 {
			let yearLabel = UILabel(frame: CGRect(x: offset, y: 4, width: 80, height: 28))
			yearLabel.text = "\((175 + i)*10)"
//			yearLabel.font = UIFont.systemFont(ofSize: 17)
//			yearLabel.font = UIFont(name: "Rubik-Light", size: 17)
			yearLabel.font = UIFont.rubik(.light, size: 26)
			yearLabel.textColor = .white
			yearLabel.textAlignment = .center
			contentRect = contentRect.union(yearLabel.frame)
			self.timeScrollView.addSubview(yearLabel)

			let focusYearLabel = yearLabel.clone()
			focusYearLabel.textColor = .black
			self.focusTimeScrollView.addSubview(focusYearLabel)
			
			offset += 80
		}
		contentRect.size.width += padding
		self.timeScrollView.contentSize = contentRect.size
		
		let gradientMask = CAGradientLayer()
		gradientMask.frame = self.timeScrollView.superview!.bounds
		gradientMask.startPoint = CGPoint(x: 0.0, y: 0.5)
		gradientMask.endPoint = CGPoint(x: 1.0, y: 0.5)
		
		let relativeFocusRectWidth = 77 / gradientMask.frame.size.width
		let focusRectStart = NSNumber(value: Float(0.5 - relativeFocusRectWidth / 2))
		let focusRectEnd = NSNumber(value: Float(0.5 + relativeFocusRectWidth / 2))
		debugPrint("gradientMask.frame = \(gradientMask.frame)")
		gradientMask.locations = [0, focusRectStart, focusRectStart, focusRectEnd, focusRectEnd, 1]
		gradientMask.colors = [UIColor.clear.cgColor, UIColor.black.cgColor, UIColor.clear.cgColor, UIColor.clear.cgColor, UIColor.black.cgColor, UIColor.clear.cgColor]
		self.timeScrollView.superview!.layer.mask = gradientMask

		let focusMask = gradientMask.clone()
		focusMask.colors = [UIColor.clear.cgColor, UIColor.clear.cgColor, UIColor.black.cgColor, UIColor.black.cgColor, UIColor.clear.cgColor, UIColor.clear.cgColor]
		self.focusTimeScrollView.superview!.layer.mask = focusMask

		let focusBackgroundLayer = gradientMask.clone()
		focusBackgroundLayer.colors = [UIColor.clear.cgColor, UIColor.clear.cgColor, UIColor(hexString: "7294b4").withAlphaComponent(0.6).cgColor, UIColor(hexString: "949ab0").withAlphaComponent(0.6).cgColor, UIColor.clear.cgColor, UIColor.clear.cgColor]
		self.focusTimeScrollView.superview!.layer.insertSublayer(focusBackgroundLayer, at: 0)
		
	}
	
	func placeGlobe() {

		focusSquare?.removeFromParentNode()
		focusSquare?.previewGlobe.removeFromParentNode()

		if globe.parent == nil {
			sceneView.scene.rootNode.addChildNode(globe)
		}

		if let lastFocusSquarePos = self.focusSquare?.lastPosition {
			self.setNewVirtualObjectPosition(lastFocusSquarePos)
		} else {
			self.setNewVirtualObjectPosition(SCNVector3Zero)
		}
		globeState = .placed
		textManager.showHideMessage(hide: true, animated: true)

        setThermometer()
        
		UIView.animate(withDuration: 0.5, animations: {
			self.globeControlPanel.alpha = 1
//            self.thermometerContainer.alpha = 1
		}) { (_) in
			self.globeControlPanel.isUserInteractionEnabled = true
		}
	}
	
	func resetGlobe() {
		
		debugPrint("\(#function)")
		
		globe.removeFromParentNode()

		if globeState == .placed {
			globeState = .loaded
		}
		
		timeScrollView.setContentOffset(.zero, animated: false)
		
		globeControlPanel.isUserInteractionEnabled = false
		UIView.animate(withDuration: 0.5, animations: {
			self.globeControlPanel.alpha = 0
//            self.thermometerContainer.alpha = 0
//			self.thermometerCO2CounterPanel.alpha = 0
//			self.thermometerCO2CounterLabel.alpha = 0
//			self.thermometerThreshold1DegPanel.alpha = 0
//			self.thermometerThreshold2DegPanel.alpha = 0
			self.setPanelVisibilities()
		}) { (_) in
			self.climatePolicySwitch.setOn(false, animated: false)
			self.globe.setYear(0, climateSimulation: false)
		}
	}
	
	var currentYear = 0
	
	func scrollViewDidScroll(_ scrollView: UIScrollView) {
		if autoplayTimer != nil { return }
		
		switch scrollView {
		
		case timeScrollView:
			focusTimeScrollView.contentOffset = timeScrollView.contentOffset
            debugPrint("\(#function): contentOffset = \(timeScrollView.contentOffset)")
			
			currentYear = min(max(0, Int(round(350 * timeScrollView.contentOffset.x / 2_800))), 349)
			
			setThermometer()
			setPanelVisibilities()
//			setGlobe()

		case introductionScrollView:
			introductionPageControl.goTo(Int(round(Float(scrollView.contentOffset.x / scrollView.frame.size.width))))
		
		default:
			break
		}
		
		
		
		
//		debugPrint("\(#function)")
//		setGlobe()
	}

	func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
		autoplayTimer = nil
	}
	
	func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
		debugPrint("\(#function) – decelerate: \(decelerate)")
		if decelerate { return }
		setGlobe()
	}

//	func scrollViewWillBeginDecelerating(_ scrollView: UIScrollView) {
//		if scrollView == introductionScrollView { return }
//		scrollView.setContentOffset(scrollView.contentOffset, animated: false)
//		setGlobe()
//	}
	
	func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
		debugPrint("\(#function)")
		setGlobe()
	}
	
//	var thermometerCO2CounterPanelVisibility = false
//	// 1885 to 2008
//	let thermometerCO2CounterPanelVisibleFromYear = 134
//	let thermometerCO2CounterPanelVisibleToYear = 257
//
//	var thermometerThreshold1DegVisibility = false
//	// from 2011
//	let thermometerThreshold1DegVisibleFromYear = 260
//
//	var thermometerThreshold2DegVisibility = false
//	// from 2021
//	let thermometerThreshold2DegVisibleFromYear = 270
//
//	var climatePolicySimulationVisibility = false
//	// from 2018
//	let climatePolicySimulationVisibleFromYear = 267
	
	var panelVisibility = [10: false, 20: false, 30: false, 40: false, 50: false]
	var panelVisibleFromYear = [10: 267, 20: 134, 30: 260, 40: 270, 50: 134]
	var panelVisibleToYear = [10: 350, 20: 257, 30: 350, 40: 350, 50: 350]
	
	func setPanelVisibilities() {
		setPanelVisibility(panel: thermometerPanel)
		setPanelVisibility(panel: climatePolicySimulationPanel)
		setPanelVisibility(panel: thermometerCO2CounterPanel)
		setPanelVisibility(panel: thermometerThreshold1DegPanel)
		setPanelVisibility(panel: thermometerThreshold2DegPanel)
	}
	
	
	func setPanelVisibility(panel: UIView) {
		guard
			let visibility = panelVisibility[panel.tag],
			let visibleFromYear = panelVisibleFromYear[panel.tag],
			let visibleToYear = panelVisibleToYear[panel.tag]
		else { return }
		
		let visible = visibleFromYear < currentYear && currentYear < visibleToYear
		if visible == visibility { return }
		panelVisibility[panel.tag] = visible
		
		panel.isHidden = false
		UIView.animate(withDuration: 0.5,
					   delay: 0,
					   options: .beginFromCurrentState,
					   animations: { panel.alpha = visible ? 1 : 0 }) { (_) in
						if !visible { panel.isHidden = true }
		}
	}
	
	func setGlobe() {
		debugPrint("Setting globe to year \(currentYear)")
		globe.setYear(currentYear)
	}
	
	@IBAction func autoplayButtonPressed(_ sender: Any) {
		
		if autoplayTimer != nil {
			stopAutoplay()
		}

		else {
			startAutoplay()
		}
	}
	
	func startAutoplay() {
		
		autoplayButton.setTitle("◼︎", for: .normal)
		autoplayButton.contentEdgeInsets = UIEdgeInsets.init(top: 0, left: 0, bottom: 5, right: 0)
		
//		let scrollViewLeftToTravel = timeScrollView.contentSize.width - timeScrollView.contentOffset.x - timeScrollView.frame.size.width
		let labelWidth = timeScrollView.subviews.first?.frame.size.width ?? 80
		
//		debugPrint("Animating with duration \(TimeInterval(scrollViewLeftToTravel/labelWidth))")

		let autoplayInterval: TimeInterval = 1
		let autoplayStep = labelWidth * 0.4 * CGFloat(autoplayInterval)
		
		autoplayTimer = Timer.scheduledTimer(withTimeInterval: autoplayInterval, repeats: true, block: { (_) in
			var newRect = self.timeScrollView.bounds
			newRect.origin.x += min(autoplayStep, self.timeScrollView.contentSize.width - self.timeScrollView.frame.size.width - self.timeScrollView.contentOffset.x)
			UIView.animate(withDuration: autoplayInterval, delay: 0, options: UIView.AnimationOptions.curveLinear, animations: {
				self.timeScrollView.scrollRectToVisible(newRect, animated: false)
			}, completion: { (_) in
				self.setGlobe()
			})
			if (self.timeScrollView.contentSize.width - self.timeScrollView.frame.size.width - self.timeScrollView.contentOffset.x /*< autoplayStep*/ <= 0) {
				self.stopAutoplay()
			}
		})
		autoplayTimer?.fire()
		
	}
	
	func stopAutoplay() {
		autoplayButton.setTitle("▶︎", for: .normal)
		autoplayButton.contentEdgeInsets = UIEdgeInsets.init(top: 0, left: 4, bottom: 0, right: 0)
		
		autoplayTimer = nil
//		timeScrollView.layer.removeAllAnimations()
	}
	
    // MARK: - Planes
	
	var planes = [ARPlaneAnchor: Plane]()
	
    func addPlane(node: SCNNode, anchor: ARPlaneAnchor) {
		
//		let pos = SCNVector3.positionFromTransform(anchor.transform)
//		textManager.showDebugMessage("NEW SURFACE DETECTED AT \(pos.friendlyString())")
		
		let plane = Plane(anchor, showDebugVisuals)
		
		planes[anchor] = plane
		node.addChildNode(plane)
		
		textManager.cancelScheduledMessage(forType: .planeEstimation)
//		textManager.showMessage("SURFACE DETECTED")
//		if virtualObject == nil {
//			textManager.scheduleMessage("TAP + TO PLACE AN OBJECT", inSeconds: 7.5, messageType: .contentPlacement)
//		}
	}
		
    func updatePlane(anchor: ARPlaneAnchor) {
        if let plane = planes[anchor] {
			plane.update(anchor)
		}
	}
			
    func removePlane(anchor: ARPlaneAnchor) {
		if let plane = planes.removeValue(forKey: anchor) {
			plane.removeFromParentNode()
        }
    }
	
	func restartPlaneDetection() {
		
		// configure session
		if let worldSessionConfig = sessionConfig as? ARWorldTrackingConfiguration {
			worldSessionConfig.planeDetection = .horizontal
			session.run(worldSessionConfig, options: [.resetTracking, .removeExistingAnchors])
		}
		
		// reset timer
		if trackingFallbackTimer != nil {
			trackingFallbackTimer!.invalidate()
			trackingFallbackTimer = nil
		}
		
		textManager.scheduleMessage("FIND A SURFACE TO PLACE AN OBJECT",
		                            inSeconds: 7.5,
		                            messageType: .planeEstimation)
	}

    // MARK: - Focus Square
    var focusSquare: FocusSquare?
	
    func setupFocusSquare() {
		debugPrint("\(#function)")
		focusSquare?.isHidden = true
		focusSquare?.removeFromParentNode()
		focusSquare = FocusSquare()
		sceneView.scene.rootNode.addChildNode(focusSquare!)
//		focusSquare?.printReverseVisibilityHierarchy()
		
		textManager.scheduleMessage("TRY MOVING LEFT OR RIGHT", inSeconds: 5.0, messageType: .focusSquare)
    }
	
	func updateFocusSquare() {
		if globe.parent != nil { return }
		
		var timestamp = Date()
		timestamp = print(intervalSince: timestamp, string: "    Flag1")
		guard let screenCenter = screenCenter else { return }
		timestamp = print(intervalSince: timestamp, string: "    Flag2")
		var insideFrustum = false
		if let coreGlobe = globe.coreGlobe {
			insideFrustum = sceneView.isNode(coreGlobe, insideFrustumOf: sceneView.pointOfView!)
		}
		timestamp = print(intervalSince: timestamp,	 string: "    Flag3")
		if insideFrustum {
			focusSquare?.hide()
		} else {
			focusSquare?.unhide()
		}
//		timestamp = print(intervalSince: timestamp, string: "    Flag4")
		let (worldPos, planeAnchor, _) = worldPositionFromScreenPosition(screenCenter, objectPos: focusSquare?.position)
//		timestamp = print(intervalSince: timestamp, string: "    Flag5")
		if let worldPos = worldPos {
			focusSquare?.update(for: worldPos, planeAnchor: planeAnchor, camera: self.session.currentFrame?.camera)
			textManager.cancelScheduledMessage(forType: .focusSquare)
		}
//		timestamp = print(intervalSince: timestamp, string: "    Flag6")
	}
	
	// MARK: - Hit Test Visualization
	
	var hitTestVisualization: HitTestVisualization?
	
	var showHitTestAPIVisualization = UserDefaults.standard.bool(for: .showHitTestAPI) {
		didSet {
			UserDefaults.standard.set(showHitTestAPIVisualization, for: .showHitTestAPI)
			if showHitTestAPIVisualization {
				hitTestVisualization = HitTestVisualization(sceneView: sceneView)
			} else {
				hitTestVisualization = nil
			}
		}
	}
	
    // MARK: - Debug Visualizations
	
	@IBOutlet var featurePointCountLabel: UILabel!
	
	func refreshFeaturePoints() {
		guard showDebugVisuals else {
			return
		}
		
		// retrieve cloud
		guard let cloud = session.currentFrame?.rawFeaturePoints else {
			return
		}
		
		DispatchQueue.main.async {
			self.featurePointCountLabel.text = "Features: \(cloud.points.count)".uppercased()
		}
	}
	
    var showDebugVisuals: Bool = UserDefaults.standard.bool(for: .debugMode) {
        didSet {
			featurePointCountLabel.isHidden = !showDebugVisuals
			debugMessageLabel.isHidden = !showDebugVisuals
			messagePanel.isHidden = !showDebugVisuals
			planes.values.forEach { $0.showDebugVisualization(showDebugVisuals) }
			
			if showDebugVisuals {
				sceneView.debugOptions = [SCNDebugOptions.showFeaturePoints, SCNDebugOptions.showWorldOrigin]
			} else {
				sceneView.debugOptions = []
			}
			
            // save pref
            UserDefaults.standard.set(showDebugVisuals, for: .debugMode)
        }
    }
    
    func setupDebug() {
		// Set appearance of debug output panel
		messagePanel.layer.cornerRadius = 3.0
		messagePanel.clipsToBounds = true
    }
    
    // MARK: - UI Elements and Actions
	
	@IBOutlet weak var messagePanel: UIView!
	@IBOutlet weak var messageLabel: UILabel!
	@IBOutlet weak var debugMessageLabel: UILabel!
	
	var textManager: TextManager!
	
    func setupUIControls() {
		textManager = TextManager(viewController: self)
		
        // hide debug message view
		debugMessageLabel.isHidden = true
		
		featurePointCountLabel.text = ""
		debugMessageLabel.text = ""
		messageLabel.text = ""
    }
	
	@IBOutlet weak var restartExperienceButton: UIButton!
	var restartExperienceButtonIsEnabled = true
	
	@IBAction func restartExperience(_ sender: Any) {
		
		guard restartExperienceButtonIsEnabled, !isLoadingObject else {
			return
		}
		
		DispatchQueue.main.async {
			self.restartExperienceButtonIsEnabled = false
			
			self.textManager.cancelAllScheduledMessages()
			self.textManager.dismissPresentedAlert()
//			self.textManager.showMessage("STARTING A NEW SESSION")
			self.use3DOFTracking = false
			
			debugPrint("FLAG 3")
			self.resetVirtualObject()

			self.setupFocusSquare()
			self.restartPlaneDetection()
			
//			self.restartExperienceButton.setImage(#imageLiteral(resourceName: "restart"), for: [])
			
			// Disable Restart button for five seconds in order to give the session enough time to restart.
			DispatchQueue.main.asyncAfter(deadline: .now() + 5.0, execute: {
				self.restartExperienceButtonIsEnabled = true
			})
		}
	}
	
	@IBOutlet weak var screenshotButton: UIButton!
	
	@IBAction func takeScreenshot() {
		guard screenshotButton.isEnabled else {
			return
		}
		
		let takeScreenshotBlock = {
			UIImageWriteToSavedPhotosAlbum(self.sceneView.snapshot(), nil, nil, nil)
			DispatchQueue.main.async {
				// Briefly flash the screen.
				let flashOverlay = UIView(frame: self.sceneView.frame)
				flashOverlay.backgroundColor = UIColor.white
				self.sceneView.addSubview(flashOverlay)
				UIView.animate(withDuration: 0.25, animations: {
					flashOverlay.alpha = 0.0
				}, completion: { _ in
					flashOverlay.removeFromSuperview()
				})
			}
		}
		
		switch PHPhotoLibrary.authorizationStatus() {
		case .authorized, .limited:
			takeScreenshotBlock()
		case .restricted, .denied:
			let title = "Photos access denied"
			let message = "Please enable Photos access for this application in Settings > Privacy to allow saving screenshots."
			textManager.showAlert(title: title, message: message)
		case .notDetermined:
			PHPhotoLibrary.requestAuthorization({ (authorizationStatus) in
				if authorizationStatus == .authorized {
					takeScreenshotBlock()
				}
			})
		}
	}

    // MARK: - Thermometer
    
	@IBOutlet weak var thermometerPanel: UIView!
	@IBOutlet weak var thermometerContainer: UIView!
    @IBOutlet weak var thermometerMercury: UIImageView!
    @IBOutlet weak var thermometerInnerGlow: UIImageView!
	@IBOutlet weak var thermometerCO2CounterPanel: UIView!
	@IBOutlet weak var thermometerCO2CounterLabel: UILabel!
	@IBOutlet weak var thermometerThreshold1DegPanel: UIView!
	@IBOutlet weak var thermometerThreshold2DegPanel: UIView!
	
//    let maxBudget: CGFloat = 6_562_688
	
	func setupThermometerCO2CounterLabel() {
		
		let animation = CATransition()
		animation.type = .fade
		animation.duration = 0.75
		thermometerCO2CounterLabel.layer.add(animation, forKey: "kCATransitionFade")
	}
	
    func frame(from megatons: CGFloat) -> CGRect {
		let maxBudget = CGFloat((Const.globalCarbonAccumulatedBASE.last ?? 1) * Const.cco2MassFactor)
		let width = thermometerContainer.frame.size.width
        let height = min(max(0, thermometerMercury.image!.size.height * megatons / maxBudget), thermometerMercury.image!.size.height)
        let y = thermometerContainer.frame.size.height - height
        return CGRect(x: 0, y: y, width: width, height: height)
    }
    
    func setThermometer(/*_ megatons: Float, animated: Bool = false*/) {
		if currentYear >= globalCarbonAccumulated().count {
			return
		}

		let megatons = globalCarbonAccumulated()[currentYear] * Const.cco2MassFactor
		debugPrint("\(#function): \(megatons) Mt")
		

        let newFrame = frame(from: CGFloat(megatons))
		
		let animated = abs(newFrame.size.height - thermometerMercury.frame.size.height) > 1

		UIView.animate(withDuration: animated ? 0.2 : 0, delay: 0, options: .beginFromCurrentState, animations: {
			self.thermometerMercury.frame = newFrame
			self.thermometerInnerGlow.frame = newFrame
		}, completion: nil)

		thermometerCO2CounterLabel.fadeTransition(animated ? 0.2 : 0)
		thermometerCO2CounterLabel.text = String(Int(round(megatons)))
	}
	
	// MARK: - Climate Policy Simulation
	
	func globalCarbonAccumulated() -> [Float] {
		return climatePolicySwitch.isOn ? Const.globalCarbonAccumulated26 : Const.globalCarbonAccumulatedBASE
	}
	
	@IBAction func climatePolicySimulationSwitchValueChanged(_ sender: UISwitch) {
		self.setThermometer()
		self.globe.setYear(self.currentYear, climateSimulation: sender.isOn)
	}
	
	// MARK: - Overlays
	
	@IBOutlet weak var overlayBackground: UIButton!
	var overlayIsActive = false
	
	enum Overlay {
		case none, menu, intro, credits
	}
	
	var activeOverlay = Overlay.none {
		willSet {
			self.overlayIsActive = self.activeOverlay != .none
		}
		didSet {
			if (self.activeOverlay != .none) != self.overlayIsActive { self.setOverlayBackground() }
		}
	}

	func setOverlayBackground() {
		let activate = self.activeOverlay != .none
		self.overlayBackground.isUserInteractionEnabled = activate
		UIView.animate(withDuration: 0.3) {
			self.overlayBackground.alpha = activate ? 1 : 0
		}
	}
	
	@IBAction func dismissOverlay(_ sender: Any) {
		switch activeOverlay {
		case .menu:
			dismissMenu()
		case .intro:
			dismissIntroduction()
		case .credits:
			dismissCredits()
		case .none:
			debugPrint("ERROR: Overlay background should not be enabled now.")
		}
		activeOverlay = .none
	}
	
	// MARK: - Menu
	
	@IBOutlet weak var menuContainer: UIView!
	@IBOutlet weak var menuContainerHeight: NSLayoutConstraint!
	@IBOutlet var menuView: UIView!
	@IBOutlet var menuPanel: UIView!
	@IBOutlet weak var menuSwitchDisplayLocalData: UISwitch!
	
	@IBOutlet weak var menuButtonBars: UIView!
	@IBOutlet weak var menuButtonBarTop: UIView!
	@IBOutlet weak var menuButtonBarCenter0: UIView!
	@IBOutlet weak var menuButtonBarCenter1: UIView!
	@IBOutlet weak var menuButtonBarBottom: UIView!
	
	var topInset: CGFloat { return max(20, UIApplication.shared.keyWindow?.safeAreaInsets.top ?? 0) }
	var menuHiddenPosition: CGFloat {
		debugPrint("menuHiddenPosition: \(menuContainerHeight.constant) - \(menuView.frame.size.height) + \(topInset) = \(menuContainerHeight.constant - menuView.frame.size.height + topInset)")
		return menuContainerHeight.constant - menuView.frame.size.height + topInset }
//	var menuShowingPosition: CGFloat { return -topInset }
	
	func setupMenu() {
		menuView.frame.size.width = view.frame.size.width
		menuView.frame.origin.y = menuHiddenPosition
		menuContainer.addSubview(menuView)
		
		menuPanel.alpha = 0
		
		menuSwitchDisplayLocalData.isOn = UserDefaults.standard.bool(for: .displayLocalData)
	}
	
	func presentMenu() {
		
		activeOverlay = .menu

		debugPrint("\(#function)")
		UIView.animate(withDuration: 0.5) {
			self.menuView.frame.origin.y = -self.topInset
			self.menuPanel.alpha = 1
			self.menuContainerHeight.constant = self.menuView.frame.size.height + self.topInset
		}
		
		UIView.animate(withDuration: 0.25) {
			self.menuButtonBarTop.alpha = 0
			self.menuButtonBarTop.frame.origin.y = 14
			self.menuButtonBarCenter0.transform = CGAffineTransform(rotationAngle: .pi/4)
			self.menuButtonBarCenter1.transform = CGAffineTransform(rotationAngle: -.pi/4)
			self.menuButtonBarBottom.alpha = 0
			self.menuButtonBarBottom.frame.origin.y = 14
		}
		
	}
	
	func dismissMenu() {

		self.menuContainerHeight.constant = 25
		UIView.animate(withDuration: 0.5) {
			self.menuView.frame.origin.y = self.menuHiddenPosition
			self.menuPanel.alpha = 0
		}

		UIView.animate(withDuration: 0.25) {
			self.menuButtonBarTop.alpha = 1
			self.menuButtonBarTop.frame.origin.y = 4
			self.menuButtonBarCenter0.transform = CGAffineTransform(rotationAngle: 0)
			self.menuButtonBarCenter1.transform = CGAffineTransform(rotationAngle: 0)
			self.menuButtonBarBottom.alpha = 1
			self.menuButtonBarBottom.frame.origin.y = 18
		}
		
	}

	@IBAction func menuButtonPressed(_ sender: UIButton) {
		if activeOverlay == .none {
			presentMenu()
		}
		else {
			dismissOverlay(sender)
		}
	}

	@IBAction func menuButtonIntroPressed(_ sender: Any) {
		dismissMenu()
		Timer.scheduledTimer(withTimeInterval: 0.25, repeats: false) { (_) in
			self.presentIntroduction()
		}
	}
	
	@IBAction func menuButtonCreditsPressed(_ sender: Any) {
		dismissMenu()
		Timer.scheduledTimer(withTimeInterval: 0.25, repeats: false) { (_) in
			self.presentCredits()
		}
	}
	
	@IBAction func menuSwitchDisplayLocalDataValueChanged(_ sender: UISwitch) {
		
		UserDefaults.standard.set(sender.isOn, for: .displayLocalData)
		
//		if let globe = virtualObject as? Globe {
			globe.displayTooltips = sender.isOn
//		}
	}

	@IBAction func menuButtonRestartExperiencePressed(_ sender: Any) {
		restartExperience(sender)
		dismissOverlay(sender)
	}

	// MARK: - Introduction
	
	@IBOutlet weak var introductionPanel: UIView!
	@IBOutlet weak var introductionScrollView: UIScrollView!
	@IBOutlet weak var introductionPageControl: UIPageControl!
	@IBOutlet weak var showIntroductionOnStartupButton: UIButton!
	
	func setupIntroduction() {
		introductionPanel.alpha = 0
		view.addSubview(introductionPanel)
		introductionPanel.center = self.view.center
		introductionPanel.center.y += 100
	}
	
	func presentIntroduction() {
		
		activeOverlay = .intro
		
		if introductionPanel.superview == nil { setupIntroduction() }
		
		introductionScrollView.contentOffset.x = 0
		UIView.animate(withDuration: 0.3, animations: {
			self.introductionPanel.alpha = 1
			self.introductionPanel.center = self.view.center
			self.menuButtonBars.alpha = 0
		})
		
		debugPrint("introductionScrollView contentSize: \(introductionScrollView.contentSize)")
	}
	
	func dismissIntroduction() {

		UIView.animate(withDuration: 0.3, animations: {
			self.introductionPanel.alpha = 0
//			self.introductionPanel.center = self.view.center
			self.introductionPanel.center.y += 100
			self.menuButtonBars.alpha = 1
		})
	}
	
	func checkIntroductionVisible(_ flag: String) {
		
		var subviewIndex = -1
		var subviewCount = 0
		
		if let superview = introductionPanel.superview {
			subviewCount = superview.subviews.count
			for i in 0 ..< subviewCount {
				if superview.subviews[i] == introductionPanel {
					subviewIndex = i
					break
				}
			}
		}
		
		debugPrint("\(flag) – introductionPanel: \(introductionPanel.frame) index in superview: \(subviewIndex)/\(subviewCount), alpha: \(introductionPanel.alpha), hidden: \(introductionPanel.isHidden)")
		debugPrint("introductionBackground: \(overlayBackground.frame)")
	}

	@IBAction func showIntroductionOnStartupButtonPressed(_ sender: Any) {
		UserDefaults.standard.set(!UserDefaults.standard.bool(for: .showIntroductionOnStartup), for: .showIntroductionOnStartup)
		setShowIntroductionOnStartupButton()
	}
	
	func setShowIntroductionOnStartupButton() {
		UIView.setAnimationsEnabled(false)
		showIntroductionOnStartupButton.setTitle(UserDefaults.standard.bool(for: .showIntroductionOnStartup) ? "◉" : "◎", for: .normal)
		UIView.setAnimationsEnabled(true)
	}
	
	// MARK: - Credits
	@IBOutlet var creditsPanel: UIView!
	@IBOutlet weak var creditsTextView: UITextView!
	
	func styled(_ string: String, _ fontStyle: UIFont.FontStyle, _ size: CGFloat) -> NSAttributedString {
		
//		return StyledString(string).with(font: UIFont.rubik(fontStyle, size: size))
		return string.withFont(UIFont.rubik(fontStyle, size: size)).withTextColor(.white)
	}
	
	func setupCredits() {
		
		creditsTextView.attributedText =
//            styled("\n\nDesign and Concept\n", .light, 15) +
            styled("\nDesign and Concept\n", .light, 15) +
			styled("Julian Braun\n\n", .medium, 15) +
			styled("Development and Concept\n", .light, 15) +
			styled("Ekkehard Petzold\n\n", .medium, 15) +
			styled("Creative Lead\n", .light, 15) +
			styled("Boris Müller (FHP)\n\n", .medium, 15) +
			styled("Scientific Lead\n", .light, 15) +
			styled("Elmar Kriegler (PIK)\n\n", .medium, 15) +
            styled("Project Website\n", .light, 15) +
            styled("uclab.fh-potsdam.de/projects/co2", .medium, 15)
//            styled("SOURCES\n\n", .light, 18) +
//            styled("CO2 Emissions from Fossil Fuel Burning and Cement Manufacture 1751-2013\n", .medium, 13) +
//            styled("Carbon Dioxide Information Analysis Center (CDIAC), CO2 Emissions from Fossil-Fuel Burning and Cement Manufacture 1751-2013, DOI: 10.3334/CDIAC/ffe.ndp058.2016\n\n", .light, 13) +
//            styled("21st Century Baseline Projection of CO2 Emissions from Fossil Fuel Combustion and Industrial Processes Global Greenhouse Gas Emissions in 2050 in a 2°C Scenario\n", .medium, 13) +
//            styled("Potsdam Institute for Climate Impact Research (PIK), REMIND-MAgPIE model projections, SSP2 baseline and 2°C scenario. Kriegler et al., Global Environmental Change 42: 297-315, 2017, DOI: 10.1016/j.gloenvcha.2016.05.015\n\n\n", .light, 13)
		
        creditsTextView.linkTextAttributes = [.underlineColor: UIColor.white]
        
//        guard let textSuperview = creditsTextView.superview else { return }
//        let gradientMask = CAGradientLayer()
//        gradientMask.frame = textSuperview.bounds
//        gradientMask.locations = [0, 0.16, 0.84, 1]
//        gradientMask.colors = [UIColor.clear.cgColor, UIColor.black.cgColor, UIColor.black.cgColor, UIColor.clear.cgColor]
//        textSuperview.layer.mask = gradientMask
		
		
		creditsPanel.alpha = 0
		view.addSubview(creditsPanel)
		creditsPanel.center = self.view.center
		creditsPanel.center.y += 100
		
		
	}

	func presentCredits() {
		
		activeOverlay = .credits
		
		if creditsPanel.superview == nil { setupCredits() }
		
		creditsTextView.contentOffset.y = 0
		UIView.animate(withDuration: 0.3, animations: {
			self.creditsPanel.alpha = 1
			self.creditsPanel.center = self.view.center
			self.menuButtonBars.alpha = 0
		})
	}
	
	func dismissCredits() {
		
		UIView.animate(withDuration: 0.3, animations: {
			self.creditsPanel.alpha = 0
			self.creditsPanel.center.y += 100
			self.menuButtonBars.alpha = 1
		})
	}


	// MARK: - Settings
	
//	@IBOutlet weak var settingsButton: UIButton!
	
	@IBAction func showSettings(_ button: UIButton) {
		let storyboard = UIStoryboard(name: "Main", bundle: nil)
		guard let settingsViewController = storyboard.instantiateViewController(withIdentifier: "settingsViewController") as? SettingsViewController else {
			return
		}
		
		let barButtonItem = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(dismissSettings))
		settingsViewController.navigationItem.rightBarButtonItem = barButtonItem
		settingsViewController.title = "Options"
		
		let navigationController = UINavigationController(rootViewController: settingsViewController)
		navigationController.modalPresentationStyle = .popover
		navigationController.popoverPresentationController?.delegate = self
		navigationController.preferredContentSize = CGSize(width: sceneView.bounds.size.width - 20, height: sceneView.bounds.size.height - 50)
		self.present(navigationController, animated: true, completion: nil)
		
//		navigationController.popoverPresentationController?.sourceView = settingsButton
//		navigationController.popoverPresentationController?.sourceRect = settingsButton.bounds
	}
	
    @objc func dismissSettings() {
		self.dismiss(animated: true, completion: nil)
		updateSettings()
	}
	
	private func updateSettings() {
		let defaults = UserDefaults.standard
		
		showDebugVisuals = defaults.bool(for: .debugMode)
//		toggleAmbientLightEstimation(defaults.bool(for: .ambientLightEstimation))
		dragOnInfinitePlanesEnabled = defaults.bool(for: .dragOnInfinitePlanes)
		showHitTestAPIVisualization = defaults.bool(for: .showHitTestAPI)
		use3DOFTracking	= defaults.bool(for: .use3DOFTracking)
		use3DOFTrackingFallback = defaults.bool(for: .use3DOFFallback)
		for (_, plane) in planes {
			plane.updateOcclusionSetting()
		}
	}

	// MARK: - Error handling
	
	func displayErrorMessage(title: String, message: String, allowRestart: Bool = false) {
		// Blur the background.
		textManager.blurBackground()
		
		if allowRestart {
			// Present an alert informing about the error that has occurred.
			let restartAction = UIAlertAction(title: "Reset", style: .default) { _ in
				self.textManager.unblurBackground()
				self.restartExperience(self)
			}
			textManager.showAlert(title: title, message: message, actions: [restartAction])
		} else {
			textManager.showAlert(title: title, message: message, actions: [])
		}
	}
	
	// MARK: - UIPopoverPresentationControllerDelegate
	func adaptivePresentationStyle(for controller: UIPresentationController) -> UIModalPresentationStyle {
		return .none
	}
	
	func popoverPresentationControllerDidDismissPopover(_ popoverPresentationController: UIPopoverPresentationController) {
		updateSettings()
	}
}

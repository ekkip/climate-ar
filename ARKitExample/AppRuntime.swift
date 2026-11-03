//
//  AppRuntime.swift
//  ARKitExample
//

import UIKit

enum AppRuntime {
	/// Compile-time and runtime check for the iOS Simulator.
	static var isRunningOnSimulator: Bool {
		#if targetEnvironment(simulator)
		return true
		#else
		return ProcessInfo.processInfo.environment["SIMULATOR_DEVICE_NAME"] != nil
		#endif
	}

	/// SceneKit-only preview (no `ARSession`) — used for simulator UI testing and development.
	static var usesNonARPreview: Bool { isRunningOnSimulator }
}

enum NonARPreview {
	/// Matches standing eye height; ground is at y = 0 for scale math.
	static let cameraHeightAboveGround: Float = 1.5
	static let globeDistanceFromCamera: Float = 2.0
	/// Same factor as `setNewVirtualObjectPosition` (`deltaHeight * 0.75`).
	static let globeScaleHeightFactor: Float = 0.75

	static let sceneBackgroundColor = UIColor(red: 0.04, green: 0.10, blue: 0.22, alpha: 1.0)

	/// Fixed image-based lighting (no AR light estimate on the simulator).
	static let lightingEnvironmentIntensity: CGFloat = 5

	/// Key light for PBR globe (no AR default-light estimate on the simulator).
	static let directionalLightIntensity: CGFloat = 320
}

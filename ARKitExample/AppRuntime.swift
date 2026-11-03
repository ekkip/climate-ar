//
//  AppRuntime.swift
//  ARKitExample
//

import UIKit

enum AppRuntime {
	/// SceneKit-only preview (no `ARSession`) on Simulator and when the iOS app runs on Mac.
	static var usesNonARPreview: Bool {
		#if targetEnvironment(simulator)
		return true
		#else
		return ProcessInfo.processInfo.isiOSAppOnMac
		#endif
	}
}

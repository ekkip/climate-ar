/*
See LICENSE folder for this sample's licensing information.

Abstract:
Application delegate class.
*/

import UIKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

	func application(
		_ application: UIApplication,
		configurationForConnecting connectingSceneSession: UISceneSession,
		options: UIScene.ConnectionOptions
	) -> UISceneConfiguration {
		UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
	}

	func application(
		_ application: UIApplication,
		didDiscardSceneSessions sceneSessions: Set<UISceneSession>
	) {
	}

//	func application(
//		_ application: UIApplication,
//		supportedInterfaceOrientationsFor window: UIWindow?
//	) -> UIInterfaceOrientationMask {
//		guard let window else {
//			return .portrait
//		}
//
//		let size = window.screen.bounds.size
//		let shorterDimension = min(size.width, size.height)
//
//		if shorterDimension < 500 {
//			return .portrait
//		} else {
//			return .all
//		}
//	}
}

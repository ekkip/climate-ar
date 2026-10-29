/*
See LICENSE folder for this sample's licensing information.

Abstract:
Scene delegate for window lifecycle.
*/

import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

	var window: UIWindow?

	func scene(
		_ scene: UIScene,
		willConnectTo session: UISceneSession,
		options connectionOptions: UIScene.ConnectionOptions
	) {
		guard let windowScene = scene as? UIWindowScene else { return }
		let launchStarted = Date()
		let window = UIWindow(windowScene: windowScene)
		window.rootViewController = ViewController()
		window.makeKeyAndVisible()
		self.window = window
		showLaunchScreenUntilMinimumDuration(on: window, launchStarted: launchStarted)
	}

	private func showLaunchScreenUntilMinimumDuration(on window: UIWindow, launchStarted: Date) {
		guard
			let launchViewController = UIStoryboard(name: "LaunchScreen", bundle: nil).instantiateInitialViewController(),
			let launchView = launchViewController.view
		else {
			return
		}

		launchView.frame = window.bounds
		launchView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
		window.addSubview(launchView)

		let elapsed = Date().timeIntervalSince(launchStarted)
		let remaining = max(0, StyleParams.minimumLaunchScreenDuration - elapsed)
		DispatchQueue.main.asyncAfter(deadline: .now() + remaining) {
			UIView.animate(withDuration: 0.25, animations: {
				launchView.alpha = 0
			}, completion: { _ in
				launchView.removeFromSuperview()
			})
		}
	}

//	@available(iOS 16.0, *)
//	func windowScene(
//		_ windowScene: UIWindowScene,
//		didUpdateEffectiveGeometry previousEffectiveGeometry: UIWindowScene.Geometry
//	) {
//		guard let window = windowScene.windows.first(where: \.isKeyWindow),
//			  let rootVC = window.rootViewController else {
//			return
//		}
//
//		let size = window.screen.bounds.size
//		let shorterDimension = min(size.width, size.height)
//
//		let orientations: UIInterfaceOrientationMask =
//			shorterDimension < 500 ? .portrait : .all
//
//		// Update the supported orientations first.
//		rootVC.setNeedsUpdateOfSupportedInterfaceOrientations()
//
//		// Then explicitly request the desired scene orientation.
//		windowScene.requestGeometryUpdate(
//			.iOS(interfaceOrientations: orientations)
//		) { error in
//			print("Orientation update rejected: \(error)")
//		}
//	}
}

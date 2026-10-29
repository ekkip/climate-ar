/*
See LICENSE folder for this sample's licensing information.

Abstract:
Installs the programmatic view hierarchy for ViewController.
*/

import UIKit

extension ViewController {

	func installViewHierarchy() {
		buildRootLayout()
		buildMenuView()
		buildIntroductionPanel()
		buildCreditsPanel()
	}
}

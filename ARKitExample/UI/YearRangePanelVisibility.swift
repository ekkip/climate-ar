/*
See LICENSE folder for this sample's licensing information.

Abstract:
Year-index visibility for timeline-linked overlay panels (thermometer, policy switch, etc.).
*/

import UIKit

/// Timeline-linked panels shown when `visibleFromYear < currentYear < visibleToYear` (calendar year ≈ 1750 + index).
enum YearRangePanelID: CaseIterable {
	/// Climate policy switch; visible after index 267 (~2018).
	case climatePolicySimulation
	/// CO₂ counter; indices 134–257 (~1885–2007).
	case co2Counter
	/// 1°C threshold label; after index 260 (~2011).
	case threshold1Deg
	/// 2°C threshold label; after index 270 (~2021).
	case threshold2Deg
	/// Main thermometer column; after index 134 (~1885).
	case thermometer
}

struct YearRangePanelState {
	let id: YearRangePanelID
	weak var panel: UIView?
	var isShown: Bool
	let visibleFromYear: Int
	let visibleToYear: Int
}

extension ViewController {

	func registerYearRangePanels() {
		guard yearRangePanelStates.isEmpty else { return }

		yearRangePanelStates = [
			YearRangePanelState(id: .climatePolicySimulation, panel: climatePolicySimulationPanel, isShown: false, visibleFromYear: 267, visibleToYear: 350),
			YearRangePanelState(id: .co2Counter, panel: thermometerCO2CounterPanel, isShown: false, visibleFromYear: 134, visibleToYear: 257),
			YearRangePanelState(id: .threshold1Deg, panel: thermometerThreshold1DegPanel, isShown: false, visibleFromYear: 260, visibleToYear: 350),
			YearRangePanelState(id: .threshold2Deg, panel: thermometerThreshold2DegPanel, isShown: false, visibleFromYear: 270, visibleToYear: 350),
			YearRangePanelState(id: .thermometer, panel: thermometerPanel, isShown: false, visibleFromYear: 134, visibleToYear: 350),
		]
	}

	func setPanelVisibilities() {
		for index in yearRangePanelStates.indices {
			setPanelVisibility(at: index)
		}
	}

	private func setPanelVisibility(at index: Int) {
		guard yearRangePanelStates.indices.contains(index),
			  let panel = yearRangePanelStates[index].panel else { return }

		let config = yearRangePanelStates[index]
		let shouldShow = config.visibleFromYear < currentYear && currentYear < config.visibleToYear
		if shouldShow == config.isShown { return }

		yearRangePanelStates[index].isShown = shouldShow

		panel.layer.removeAllAnimations()
		panel.isHidden = false
		UIView.animate(withDuration: 0.5,
					   delay: 0,
					   options: .beginFromCurrentState,
					   animations: { panel.alpha = shouldShow ? 1 : 0 }) { _ in
			guard let idx = self.yearRangePanelStates.firstIndex(where: { $0.panel === panel }) else { return }
			if !self.yearRangePanelStates[idx].isShown {
				panel.isHidden = true
			}
		}
	}
}

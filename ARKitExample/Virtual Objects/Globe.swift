//
//  Globe.swift
//  ARKitExample
//
//  Created by Ekkehard Petzold on 16.09.17.
//  Copyright © 2017 Apple. All rights reserved.
//

import Foundation
import ARKit
import SceneKit

class Globe: VirtualObject {
	
	/// Copy per-prism geometry only if shared-mesh bounds updates cause visible jank (costs ~14k geometries).
	static var privatizePrismGeometry = false
	
	/// Animate prism height only when the settled year changes by at most this many indices.
	static let maxAnimatedYearStep = 3
	
	/// true: all prisms are one mesh (one draw call) built once; heights are computed on the GPU from a value texture.
	/// false: one SceneKit node per prism (~13k draw calls at modern years), kept for A/B comparison.
	static var useMergedPrismRenderer = true
	
	private var mergedPrisms: MergedPrismLayer?
	
	private final class PolicyRefreshPerfContext {
		var session: ClimatePolicyPerfSession?
		var tick = Date()
		var animationDuration: TimeInterval = 0
	}
	
	private(set) var globePrismsLoaded = false
	private var lastRefreshedYear = 0
	
	var prisms = [Prism]()
	var coreGlobe: SCNNode?
	var gridContainer: SCNNode?
	
	var prismsWithTooltips = [Prism]()
	var displayTooltips = true

	var currentYear = 0
	
	override init() {
		super.init(modelName: "globe", fileExtension: "scn", thumbImageFilename: "globe", title: "Globe")
	}
	
	required init?(coder aDecoder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
	
	override func loadModel() {
		if globePrismsLoaded {
			GlobePerf.noteDuplicateLoadAttempt()
			return
		}
		
		#if DEBUG
		let loadStart = GlobePerf.beginGlobeLoad()
		GlobePerf.loadGeneration += 1
		#endif
		
		super.loadModel()
		
		displayTooltips = UserDefaults.standard.bool(for: .displayLocalData)
		
		guard let wrapperNode = self.childNodes.first else { return }
		
		for childNode in wrapperNode.childNodes {
			switch childNode.name ?? "---" {
			case "Grid Container":
				self.gridContainer = childNode
			case "Globe":
				self.coreGlobe = childNode
			default:
				break
			}
		}
		
		guard let globe = self.coreGlobe, let gridContainer = self.gridContainer else {
			debugPrint("Child nodes missing from the Globe scene.")
			return
		}
		
		let prismTemplate = Prism()
		prismTemplate.loadModel()
		let scaleCorrection = 1 / (prismTemplate.boundingBox.max.y - prismTemplate.boundingBox.min.y)
		
		let globeRadius = globe.scale.x * fabsf(globe.boundingBox.max.x - globe.boundingBox.min.x) / 2

		let prominentAreas = [
			61: [55: "Los Angeles Area"],
			92: [48: "Chicago Area"],
			121: [124: "Buenos Aires Area"],
			179: [38: "London Area"],
			207: [116: "Johannesburg Area"],
			219: [68: "Mekka Area"],
			319: [54: "Tokyo Area"],
			331: [123: "Sydney Area"]
		]
		
		let useMerged = Self.useMergedPrismRenderer
		var mergedCells = MergedPrismLayer.Cells()
		let rotationProbe = Prism()
		
		if useMerged {
			mergedCells.reserveCapacity(cells: 15_000, baseValues: 15_000 * 350, policyValues: 15_000 * 84)
		}
		
		let summary = RemindCellFile.read { cell in
			let lon = cell.lon
			let lat = cell.lat
			if useMerged {
				rotationProbe.setPosition(lon, lat)
				mergedCells.append(rotation: MergedPrismLayer.rotation(of: rotationProbe), years: cell.years, years26: cell.years26)
				
				// Only tooltip locations keep a node; it carries the tooltip, its own mesh stays hidden.
				guard let prominentArea = prominentAreas[lon]?[lat] else { return }
				let anchor: Prism = prismTemplate.clone()
				anchor.hideOwnMesh()
				anchor.baseRadius = globeRadius
				anchor.scaleCorrection = scaleCorrection
				anchor.years = cell.years
				anchor.years26 = cell.years26
				anchor.gridContainer = gridContainer
				anchor.setPosition(lon, lat)
				anchor.addTooltip(lon: lon, lat: lat, description: prominentArea)
				anchor.updateTooltipAnchor(year: currentYear)
				gridContainer.addChildNode(anchor)
				prismsWithTooltips.append(anchor)
				return
			}
			
			let prism: Prism = prismTemplate.clone()
			if Self.privatizePrismGeometry {
				prism.privatizeSharedGeometry()
			}
			
			prism.baseRadius = globeRadius
			prism.scaleCorrection = scaleCorrection
			prism.years = cell.years
			prism.years26 = cell.years26
			prism.gridContainer = gridContainer
			prism.setPosition(lon, lat)
			prism.setYear(currentYear, forceResize: true)
			
			if let prominentArea = prominentAreas[lon]?[lat] {
				prism.addTooltip(lon: lon, lat: lat, description: prominentArea)
				prismsWithTooltips.append(prism)
			}
			
			prisms.append(prism)
		}
		if summary == nil {
			debugPrint("[Globe] REMIND_cells.bin is missing or malformed; run Scripts/convert_remind_json.py.")
		}
		
		if useMerged {
			let shape = MergedPrismLayer.Shape(
				baseRadius: globeRadius,
				scaleCorrection: scaleCorrection,
				threshold: prismTemplate.threshold,
				widthSocket: prismTemplate.widthSocket,
				widthFactor: prismTemplate.widthFactor,
				heightFactor: prismTemplate.heightFactor
			)
			if let templateGeometry = prismTemplate.childNodes.first?.geometry,
				let layer = MergedPrismLayer(cells: mergedCells, shape: shape, templateGeometry: templateGeometry) {
				let anchors = prismsWithTooltips
				layer.onStateChanged = { state in
					for anchor in anchors {
						anchor.placeTooltip(value: anchor.value(at: state.year, policyWeight: Float(state.policy)))
					}
				}
				gridContainer.addChildNode(layer.node)
				mergedPrisms = layer
				let year = currentYear
				let policy = climatePolicy
				DispatchQueue.main.async {
					layer.update(year: year, policy: policy, duration: 0)
				}
			} else {
				debugPrint("[Globe] Prism template geometry could not be merged; no prisms will be shown.")
			}
		}
		
		globePrismsLoaded = true
		lastRefreshedYear = currentYear
		
		#if DEBUG
		let prismCount = mergedPrisms?.cellCount ?? prisms.count
		GlobePerf.assertLoadInvariants(
			prismCount: prismCount,
			gridChildCount: gridContainer.childNodes.count,
			wrapperChildCount: wrapperNode.childNodes.count
		)
		GlobePerf.endGlobeLoad(start: loadStart, prismCount: prismCount, gridChildCount: gridContainer.childNodes.count)
		#endif
	}
	
	/// Labels show whole years; heights and visibility follow the displayed state via `onStateChanged`.
	private func setTooltipLabels(year: Int, policy: Bool) {
		for anchor in prismsWithTooltips {
			anchor.setTooltipLabel(year: year, policy: policy)
		}
	}
	
	// MARK: - Scrubbing the timeline
	
	/// Settling from a fractional to a whole year after scrolling moves at most half a year.
	static let settleAfterScrubDuration: CFTimeInterval = 0.25
	
	/// Set while heights show a fractional year; the next `setYear` settles even if the rounded year is unchanged.
	private var isScrubbed = false
	
	var canUpdateYearWhileScrolling: Bool {
		return mergedPrisms != nil && LiveGlobeUpdates.isSupported
	}
	
	/// Called for every scroll step with a fractional year index; heights and tooltips follow without animation or rebuilds.
	func scrubYear(to position: Double) {
		guard let layer = mergedPrisms else { return }
		let clamped = min(max(position, 0), Double(layer.lastYear))
		isScrubbed = true
		let year = Int(clamped.rounded())
		if year != currentYear {
			currentYear = year
			setTooltipLabels(year: year, policy: climatePolicy)
		}
		layer.scrub(to: clamped, policy: climatePolicy)
	}
	
	var animating = false
	var queuedYear: Int?
	var queuedClimatePolicy: Bool?
	var pendingRefreshCompletion: (() -> Void)?
	
	var climatePolicy = false
	
	func setYear(_ year: Int, climateSimulation: Bool? = nil) {
		if let simulation = climateSimulation {
			applyClimatePolicySimulation(simulation, at: year)
			return
		}
		
		if let layer = mergedPrisms {
			guard year != currentYear || isScrubbed else { return }
			let duration = isScrubbed ? Globe.settleAfterScrubDuration : MergedPrismLayer.animationDuration
			isScrubbed = false
			currentYear = year
			MainThreadHitchMonitor.shared.beginWindow("year \(year + 1750)")
			setTooltipLabels(year: year, policy: climatePolicy)
			layer.update(year: year, policy: climatePolicy, duration: duration)
			return
		}
		
		if year == currentYear && !animating {
			return
		}
		
		if animating {
			queuedYear = year
			return
		}
		
		animating = true
		currentYear = year
		refreshPrisms(at: year, animated: true, policyToggle: false, previousClimatePolicy: nil)
	}
	
	func applyClimatePolicySimulation(_ on: Bool, at year: Int, completion: (() -> Void)? = nil) {
		if let layer = mergedPrisms {
			if year == currentYear && on == climatePolicy && !isScrubbed {
				completion?()
				return
			}
			isScrubbed = false
			currentYear = year
			climatePolicy = on
			MainThreadHitchMonitor.shared.beginWindow("policy \(on ? "on" : "off") at \(year + 1750)")
			setTooltipLabels(year: year, policy: on)
			layer.update(year: year, policy: on, completion: completion)
			return
		}
		
		if year == currentYear && on == climatePolicy && !animating {
			completion?()
			return
		}
		
		if animating {
			queuedClimatePolicy = on
			queuedYear = year
			pendingRefreshCompletion = completion
			return
		}
		
		pendingRefreshCompletion = completion
		animating = true
		currentYear = year
		let previousPolicy = climatePolicy
		climatePolicy = on
		for prism in prisms where prism.climatePolicy != on {
			prism.climatePolicy = on
		}
		refreshPrisms(at: year, animated: false, policyToggle: true, previousClimatePolicy: previousPolicy)
	}
	
	private func refreshPrisms(at year: Int, animated: Bool, policyToggle: Bool, previousClimatePolicy: Bool?) {
		let perfContext = PolicyRefreshPerfContext()
		let yearDelta = abs(year - lastRefreshedYear)
		let gridBefore = gridContainer?.childNodes.count ?? 0
		let shouldAnimateTimeline = animated && yearDelta <= Self.maxAnimatedYearStep
		perfContext.animationDuration = shouldAnimateTimeline ? 0.5 : 0
		MainThreadHitchMonitor.shared.beginWindow(policyToggle ? "policy \(climatePolicy ? "on" : "off") at \(year + 1750)" : "year \(year + 1750)")
		
		#if DEBUG
		if policyToggle {
			perfContext.session = GlobePerf.beginPolicyUpdate(
				year: year,
				calendarYear: year + 1750,
				policyOn: climatePolicy,
				prismCount: prisms.count,
				gridChildCountBefore: gridBefore
			)
			perfContext.session?.markFlags(from: &perfContext.tick)
		} else {
			perfContext.session = GlobePerf.beginYearRefresh(
				year: year,
				calendarYear: year + 1750,
				animated: shouldAnimateTimeline,
				prismCount: prisms.count,
				gridChildCountBefore: gridBefore,
				yearDelta: yearDelta
			)
			perfContext.session?.markFlags(from: &perfContext.tick)
		}
		#endif
		
		if policyToggle, let previousPolicy = previousClimatePolicy {
			refreshPrismsForPolicyToggle(
				at: year,
				previousClimatePolicy: previousPolicy,
				perfContext: perfContext
			)
			return
		}
		
		SCNTransaction.begin()
		SCNTransaction.animationDuration = perfContext.animationDuration
		SCNTransaction.animationTimingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.linear)
		
		for prism in prisms {
			prism.applyTimelineYear(year)
		}
		
		#if DEBUG
		perfContext.session?.markSetYearLoop(from: &perfContext.tick)
		#endif
		
		SCNTransaction.completionBlock = { [weak self] in
			guard let self = self else { return }
			#if DEBUG
			if var session = perfContext.session {
				session.markRemoveLoop(from: &perfContext.tick)
				let gridAfter = self.gridContainer?.childNodes.count ?? 0
				GlobePerf.endYearRefresh(
					session,
					segments: session.segments,
					gridChildCountAfter: gridAfter,
					animationDuration: perfContext.animationDuration
				)
			}
			#endif
			self.lastRefreshedYear = year
			self.finishGlobeRefreshAfterTransaction()
		}
		
		SCNTransaction.commit()
		
		#if DEBUG
		perfContext.session?.markCommit(from: &perfContext.tick)
		#endif
	}
	
	private func refreshPrismsForPolicyToggle(
		at year: Int,
		previousClimatePolicy: Bool,
		perfContext: PolicyRefreshPerfContext
	) {
		SCNTransaction.begin()
		SCNTransaction.animationDuration = 0
		SCNTransaction.animationTimingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.linear)
		
		for prism in prisms {
			if prism.shouldSkipPolicyToggle(year: year, previousClimatePolicy: previousClimatePolicy) {
				#if DEBUG
				if ClimatePolicyPerf.isPolicyUpdateActive {
					ClimatePolicyPerf.prismCounters.skippedDetachedInactive += 1
				}
				#endif
				continue
			}
			prism.setYear(
				year,
				policyToggleAtFixedYear: true,
				previousClimatePolicy: previousClimatePolicy
			)
		}
		
		#if DEBUG
		perfContext.session?.markSetYearLoop(from: &perfContext.tick)
		#endif
		
		SCNTransaction.completionBlock = { [weak self] in
			guard let self = self else { return }
			#if DEBUG
			if var session = perfContext.session {
				session.markRemoveLoop(from: &perfContext.tick)
				let gridAfter = self.gridContainer?.childNodes.count ?? 0
				ClimatePolicyPerf.endPolicyUpdate(session, segments: session.segments, gridChildCountAfter: gridAfter)
			}
			#endif
			self.finishGlobeRefreshAfterTransaction()
		}
		
		SCNTransaction.commit()
		
		#if DEBUG
		perfContext.session?.markCommit(from: &perfContext.tick)
		#endif
	}
	
	private func finishGlobeRefreshAfterTransaction() {
		animating = false
		if let queuedPolicy = queuedClimatePolicy {
			queuedClimatePolicy = nil
			let queuedYear = self.queuedYear ?? currentYear
			self.queuedYear = nil
			let completion = pendingRefreshCompletion
			pendingRefreshCompletion = nil
			applyClimatePolicySimulation(queuedPolicy, at: queuedYear, completion: completion)
			return
		}
		if let queuedYear = queuedYear {
			self.queuedYear = nil
			setYear(queuedYear)
			return
		}
		let completion = pendingRefreshCompletion
		pendingRefreshCompletion = nil
		completion?()
	}
	
	func adjustTooltipAligments(viewingAngle: Float, cameraDistance: Float) {
		var firstTooltip = true
		for prism in prismsWithTooltips {
			if let tooltip = prism.tooltip {
				if displayTooltips {
					if tooltip.parent == nil {
						prism.addChildNode(tooltip)
					}
					let deviation = (Float(tooltip.lon) - 179.5) * .pi / 180 - viewingAngle
					tooltip.align(for: deviation.modulo(from: -.pi, to: .pi))
					
					if firstTooltip {
						firstTooltip = false
					}
				}
				else {
					if tooltip.parent != nil {
						tooltip.removeFromParentNode()
					}
				}
			}
		}
	}
	
}

/// Decides whether the globe follows the timeline while scrolling or only updates after the scroll ends.
enum LiveGlobeUpdates {
	/// Launch argument `-LiveGlobeUpdates YES` / `NO` overrides the device check (e.g. in the scheme's Run arguments).
	private static let overrideKey = "LiveGlobeUpdates"
	
	/// A12 (Metal GPU family Apple 5) or newer. Scrubbing only updates two shader uniforms per scroll step,
	/// so the limit is rendering the AR globe at all rather than scrubbing.
	static let isCapableHardware: Bool = {
		guard let device = MTLCreateSystemDefaultDevice() else { return false }
		return device.supportsFamily(.apple5)
	}()
	
	/// Re-evaluated per scroll step, so the app falls back to after-scroll updates under Low Power Mode or heat.
	static var isSupported: Bool {
		if UserDefaults.standard.object(forKey: overrideKey) != nil {
			return UserDefaults.standard.bool(forKey: overrideKey)
		}
		let info = ProcessInfo.processInfo
		return isCapableHardware
			&& !info.isLowPowerModeEnabled
			&& info.thermalState.rawValue < ProcessInfo.ThermalState.serious.rawValue
	}
}

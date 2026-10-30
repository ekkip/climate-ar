//
//  ClimatePolicyPerf.swift
//  ARKitExample
//
//  DEBUG-only timing, signposts, and counters for globe load and prism refresh.
//

import Foundation
import UIKit
import Darwin
import os.signpost

#if DEBUG

struct PrismSetYearPerfCounters {
	var earlyReturn = 0
	var visibilityChange = 0
	var geometryUpdate = 0
	var tooltipUpdate = 0
	var skippedUnchanged = 0
	var attachToGrid = 0
	var detachFromGrid = 0
	var geometrySkippedRedundant = 0
	var skippedDetachedInactive = 0
	var prismsVisited = 0
	
	mutating func reset() {
		earlyReturn = 0
		visibilityChange = 0
		geometryUpdate = 0
		tooltipUpdate = 0
		skippedUnchanged = 0
		attachToGrid = 0
		detachFromGrid = 0
		geometrySkippedRedundant = 0
		skippedDetachedInactive = 0
		prismsVisited = 0
	}
}

enum GlobePerf {
	private static let log = OSLog(subsystem: Bundle.main.bundleIdentifier ?? "ARKitExample", category: "Globe")
	private static var policySignpostID: OSSignpostID = .invalid
	private static var yearSignpostID: OSSignpostID = .invalid
	private static var loadSignpostID: OSSignpostID = .invalid
	private static var animationSignpostID: OSSignpostID = .invalid
	
	static var prismCounters = PrismSetYearPerfCounters()
	static var isGlobeRefreshActive = false
	static var loadGeneration = 0
	static var concurrentLoadAttempts = 0
	
	static var isPolicyUpdateActive: Bool { isGlobeRefreshActive }
	
	static func residentMemoryMB() -> Double {
		var info = mach_task_basic_info()
		var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
		let kerr = withUnsafeMutablePointer(to: &info) {
			$0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
				task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
			}
		}
		guard kerr == KERN_SUCCESS else { return -1 }
		return Double(info.resident_size) / (1_024 * 1_024)
	}
	
	static func noteDuplicateLoadAttempt() {
		concurrentLoadAttempts += 1
		debugPrint("[GlobePerf] ignored duplicate loadModel() attempt #\(concurrentLoadAttempts) prismsAlreadyLoaded=true")
	}
	
	static func assertLoadInvariants(prismCount: Int, gridChildCount: Int, wrapperChildCount: Int) {
		debugPrint("[GlobePerf] loadGeneration=\(loadGeneration) prisms=\(prismCount) gridChildren=\(gridChildCount) wrapperChildren=\(wrapperChildCount) memMB=\(residentMemoryMB().friendlyString())")
	}
	
	static func beginGlobeLoad() -> Date {
		loadSignpostID = OSSignpostID(log: log)
		let memBefore = residentMemoryMB()
		os_signpost(.begin, log: log, name: "GlobeLoadModel", signpostID: loadSignpostID,
					"memMB=%{public}.1f", memBefore)
		return Date()
	}
	
	static func endGlobeLoad(start: Date, prismCount: Int, gridChildCount: Int) {
		let ms = Date().timeIntervalSince(start) * 1_000
		let memAfter = residentMemoryMB()
		os_signpost(.end, log: log, name: "GlobeLoadModel", signpostID: loadSignpostID,
					"ms=%{public}.1f prisms=%{public}d grid=%{public}d memMB=%{public}.1f",
					ms, prismCount, gridChildCount, memAfter)
		debugPrint("[GlobePerf] GlobeLoadModel ms=\(ms.friendlyString()) prisms=\(prismCount) gridChildren=\(gridChildCount) mem \(memAfter.friendlyString())MB")
	}
	
	static func beginPolicyUpdate(year: Int, calendarYear: Int, policyOn: Bool, prismCount: Int, gridChildCountBefore: Int) -> ClimatePolicyPerfSession {
		beginRefresh(kind: .policyToggle, year: year, calendarYear: calendarYear, policyOn: policyOn, prismCount: prismCount, gridBefore: gridChildCountBefore)
	}
	
	static func beginYearRefresh(year: Int, calendarYear: Int, animated: Bool, prismCount: Int, gridChildCountBefore: Int, yearDelta: Int) -> ClimatePolicyPerfSession {
		beginRefresh(kind: .yearScroll, year: year, calendarYear: calendarYear, policyOn: nil, prismCount: prismCount, gridBefore: gridChildCountBefore, animated: animated, yearDelta: yearDelta)
	}
	
	private static func beginRefresh(kind: ClimatePolicyPerfSession.Kind, year: Int, calendarYear: Int, policyOn: Bool?, prismCount: Int, gridBefore: Int, animated: Bool = false, yearDelta: Int = 0) -> ClimatePolicyPerfSession {
		prismCounters.reset()
		isGlobeRefreshActive = true
		let mem = residentMemoryMB()
		switch kind {
		case .policyToggle:
			policySignpostID = OSSignpostID(log: log)
			os_signpost(.begin, log: log, name: "ClimatePolicyToggle", signpostID: policySignpostID,
						"year=%{public}d calendar=%{public}d policy=%{public}d prisms=%{public}d gridBefore=%{public}d memMB=%{public}.1f",
						year, calendarYear, (policyOn ?? false) ? 1 : 0, prismCount, gridBefore, mem)
		case .yearScroll:
			yearSignpostID = OSSignpostID(log: log)
			os_signpost(.begin, log: log, name: "GlobeYearRefresh", signpostID: yearSignpostID,
						"year=%{public}d calendar=%{public}d animated=%{public}d delta=%{public}d prisms=%{public}d gridBefore=%{public}d memMB=%{public}.1f",
						year, calendarYear, animated ? 1 : 0, yearDelta, prismCount, gridBefore, mem)
		}
		return ClimatePolicyPerfSession(
			kind: kind,
			year: year,
			calendarYear: calendarYear,
			policyOn: policyOn,
			animated: animated,
			yearDelta: yearDelta,
			prismCount: prismCount,
			gridChildCountBefore: gridBefore,
			start: Date(),
			cpuPhaseEnd: Date()
		)
	}
	
	static func endPolicyUpdate(_ session: ClimatePolicyPerfSession, segments: ClimatePolicyPerfSegments, gridChildCountAfter: Int) {
		endRefresh(session, segments: segments, gridChildCountAfter: gridChildCountAfter)
	}
	
	static func endYearRefresh(_ session: ClimatePolicyPerfSession, segments: ClimatePolicyPerfSegments, gridChildCountAfter: Int, animationDuration: TimeInterval) {
		var updated = session
		updated.animationDurationSec = animationDuration
		endRefresh(updated, segments: segments, gridChildCountAfter: gridChildCountAfter)
	}
	
	private static func endRefresh(_ session: ClimatePolicyPerfSession, segments: ClimatePolicyPerfSegments, gridChildCountAfter: Int) {
		isGlobeRefreshActive = false
		let totalMs = Date().timeIntervalSince(session.start) * 1_000
		let cpuMs = session.cpuPhaseEnd.timeIntervalSince(session.start) * 1_000
		let mem = residentMemoryMB()
		
		switch session.kind {
		case .policyToggle:
			os_signpost(.end, log: log, name: "ClimatePolicyToggle", signpostID: policySignpostID,
						"cpuMs=%{public}.1f totalMs=%{public}.1f", cpuMs, totalMs)
		case .yearScroll:
			os_signpost(.end, log: log, name: "GlobeYearRefresh", signpostID: yearSignpostID,
						"cpuMs=%{public}.1f totalMs=%{public}.1f animSec=%{public}.2f", cpuMs, totalMs, session.animationDurationSec)
			if session.animationDurationSec > 0 {
				beginAnimationLifetime(duration: session.animationDurationSec, year: session.year)
			}
		}
		
		let c = prismCounters
		let tag = session.kind == .policyToggle ? "ClimatePolicyPerf" : "GlobeYearPerf"
		debugPrint("""
		[\(tag)] calendarYear=\(session.calendarYear) indexYear=\(session.year) \
		animated=\(session.animated) yearDelta=\(session.yearDelta) policyOn=\(session.policyOn?.description ?? "—") \
		prisms=\(session.prismCount) visited=\(c.prismsVisited) gridChildren \(session.gridChildCountBefore)→\(gridChildCountAfter) memMB=\(mem.friendlyString())
		timingMs: flags=\(segments.flagsMs.friendlyString()) syncLoop=\(segments.addLoopMs.friendlyString()) \
		setYearLoop=\(segments.setYearLoopMs.friendlyString()) commit=\(segments.commitMs.friendlyString()) \
		postLoop=\(segments.removeLoopMs.friendlyString()) cpu=\(cpuMs.friendlyString()) total=\(totalMs.friendlyString())
		counts: attach=\(c.attachToGrid) detach=\(c.detachFromGrid) earlyReturn=\(c.earlyReturn) \
		skippedUnchanged=\(c.skippedUnchanged) skippedDetachedInactive=\(c.skippedDetachedInactive) \
		geometrySkippedRedundant=\(c.geometrySkippedRedundant) \
		visibility=\(c.visibilityChange) geometry=\(c.geometryUpdate) tooltip=\(c.tooltipUpdate)
		""")
	}
	
	static func beginMergedBuild(year: Int, policy: Bool) -> OSSignpostID {
		let id = OSSignpostID(log: log)
		os_signpost(.begin, log: log, name: "MergedPrismBuild", signpostID: id,
					"year=%{public}d policy=%{public}d", year, policy ? 1 : 0)
		return id
	}
	
	static func endMergedBuild(_ id: OSSignpostID, visible: Int) {
		os_signpost(.end, log: log, name: "MergedPrismBuild", signpostID: id, "visible=%{public}d", visible)
	}
	
	static func logMergedUpdate(year: Int, policy: Bool, cells: Int, visible: Int, queueWaitMs: Double, buildMs: Double, applyMs: Double, totalMs: Double, coalesced: Int) {
		debugPrint("[GlobeMergedPerf] calendarYear=\(year + 1750) indexYear=\(year) policyOn=\(policy) cells=\(cells) visible=\(visible) coalesced=\(coalesced) memMB=\(residentMemoryMB().friendlyString()) \(deviceState())\ntimingMs: queueWait=\(queueWaitMs.friendlyString()) build(background)=\(buildMs.friendlyString()) apply(main)=\(applyMs.friendlyString()) total=\(totalMs.friendlyString())")
	}
	
	static func deviceState() -> String {
		let info = ProcessInfo.processInfo
		let thermal: String
		switch info.thermalState {
		case .nominal: thermal = "nominal"
		case .fair: thermal = "fair"
		case .serious: thermal = "serious"
		case .critical: thermal = "critical"
		@unknown default: thermal = "unknown"
		}
		return "thermal=\(thermal) lowPower=\(info.isLowPowerModeEnabled)"
	}
	
	private static func beginAnimationLifetime(duration: TimeInterval, year: Int) {
		animationSignpostID = OSSignpostID(log: log)
		os_signpost(.begin, log: log, name: "GlobeYearAnimation", signpostID: animationSignpostID, "year=%{public}d", year)
		DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
			os_signpost(.end, log: log, name: "GlobeYearAnimation", signpostID: animationSignpostID, "")
		}
	}
}

enum ClimatePolicyPerf {
	static var prismCounters: PrismSetYearPerfCounters {
		get { GlobePerf.prismCounters }
		set { GlobePerf.prismCounters = newValue }
	}
	static var isPolicyUpdateActive: Bool { GlobePerf.isGlobeRefreshActive }
	
	static func beginPolicyUpdate(year: Int, calendarYear: Int, policyOn: Bool, prismCount: Int, gridChildCountBefore: Int) -> ClimatePolicyPerfSession {
		GlobePerf.beginPolicyUpdate(year: year, calendarYear: calendarYear, policyOn: policyOn, prismCount: prismCount, gridChildCountBefore: gridChildCountBefore)
	}
	
	static func endPolicyUpdate(_ session: ClimatePolicyPerfSession, segments: ClimatePolicyPerfSegments, gridChildCountAfter: Int) {
		GlobePerf.endPolicyUpdate(session, segments: segments, gridChildCountAfter: gridChildCountAfter)
	}
}

/// DEBUG main-thread hitch monitor. Each `beginWindow` measures frame gaps for a fixed time after an operation starts.
final class MainThreadHitchMonitor {
	static let shared = MainThreadHitchMonitor()
	
	private static let hitchThresholdMs: Double = 50
	private static let frameMs: Double = 1_000 / 60
	
	private var displayLink: CADisplayLink?
	private var lastTimestamp: CFTimeInterval = 0
	
	private var windowLabel: String?
	private var windowDeadline: CFTimeInterval = 0
	private var windowHitches = 0
	private var windowMaxGapMs: Double = 0
	private var windowStallMs: Double = 0
	
	func start() {
		guard displayLink == nil else { return }
		lastTimestamp = 0
		displayLink = CADisplayLink(target: self, selector: #selector(tick(_:)))
		displayLink?.add(to: .main, forMode: .common)
	}
	
	func stop() {
		flushWindow()
		displayLink?.invalidate()
		displayLink = nil
	}
	
	/// Starts a new measurement window; a still-open previous window is reported immediately.
	func beginWindow(_ label: String, seconds: CFTimeInterval = 3) {
		flushWindow()
		windowLabel = label
		windowDeadline = CACurrentMediaTime() + seconds
		windowHitches = 0
		windowMaxGapMs = 0
		windowStallMs = 0
	}
	
	@objc private func tick(_ link: CADisplayLink) {
		if lastTimestamp > 0, windowLabel != nil {
			let gapMs = (link.timestamp - lastTimestamp) * 1_000
			if gapMs > MainThreadHitchMonitor.hitchThresholdMs {
				windowHitches += 1
				windowStallMs += gapMs - MainThreadHitchMonitor.frameMs
			}
			windowMaxGapMs = max(windowMaxGapMs, gapMs)
		}
		lastTimestamp = link.timestamp
		// Checked after recording, so a stall that straddles the deadline still counts for this window.
		if windowLabel != nil, link.timestamp >= windowDeadline {
			flushWindow()
		}
	}
	
	private func flushWindow() {
		guard let label = windowLabel else { return }
		windowLabel = nil
		debugPrint("[GlobePerf] hitches during \(label): gaps>50ms=\(windowHitches) maxGapMs=\(windowMaxGapMs.friendlyString()) stallMs=\(windowStallMs.friendlyString()) \(GlobePerf.deviceState())")
	}
}

struct ClimatePolicyPerfSegments {
	var flagsMs: Double = 0
	var addLoopMs: Double = 0
	var setYearLoopMs: Double = 0
	var commitMs: Double = 0
	var removeLoopMs: Double = 0
}

struct ClimatePolicyPerfSession {
	enum Kind { case policyToggle, yearScroll }
	
	let kind: Kind
	let year: Int
	let calendarYear: Int
	let policyOn: Bool?
	let animated: Bool
	let yearDelta: Int
	let prismCount: Int
	let gridChildCountBefore: Int
	let start: Date
	var cpuPhaseEnd: Date
	var animationDurationSec: TimeInterval = 0
	var segments = ClimatePolicyPerfSegments()
	
	fileprivate init(kind: Kind = .policyToggle, year: Int, calendarYear: Int, policyOn: Bool?, animated: Bool = false, yearDelta: Int = 0, prismCount: Int, gridChildCountBefore: Int, start: Date, cpuPhaseEnd: Date) {
		self.kind = kind
		self.year = year
		self.calendarYear = calendarYear
		self.policyOn = policyOn
		self.animated = animated
		self.yearDelta = yearDelta
		self.prismCount = prismCount
		self.gridChildCountBefore = gridChildCountBefore
		self.start = start
		self.cpuPhaseEnd = cpuPhaseEnd
	}
	
	mutating func markFlags(from tick: inout Date) {
		segments.flagsMs = Date().timeIntervalSince(tick) * 1_000
		tick = Date()
	}
	
	mutating func markAddLoop(from tick: inout Date) {
		segments.addLoopMs = Date().timeIntervalSince(tick) * 1_000
		tick = Date()
	}
	
	mutating func markSetYearLoop(from tick: inout Date) {
		segments.setYearLoopMs = Date().timeIntervalSince(tick) * 1_000
		tick = Date()
	}
	
	mutating func markCommit(from tick: inout Date) {
		segments.commitMs = Date().timeIntervalSince(tick) * 1_000
		tick = Date()
		cpuPhaseEnd = Date()
	}
	
	mutating func markRemoveLoop(from tick: inout Date) {
		segments.removeLoopMs = Date().timeIntervalSince(tick) * 1_000
		tick = Date()
	}
}

#else

struct PrismSetYearPerfCounters {
	mutating func reset() {}
}

enum GlobePerf {
	static func noteDuplicateLoadAttempt() {}
	static func assertLoadInvariants(prismCount: Int, gridChildCount: Int, wrapperChildCount: Int) {}
	static func beginGlobeLoad() -> Date { Date() }
	static func endGlobeLoad(start: Date, prismCount: Int, gridChildCount: Int) {}
	static func endYearRefresh(_ session: ClimatePolicyPerfSession, segments: ClimatePolicyPerfSegments, gridChildCountAfter: Int, animationDuration: TimeInterval) {}
}

enum ClimatePolicyPerf {
	static var prismCounters = PrismSetYearPerfCounters()
	static var isPolicyUpdateActive = false
	
	static func beginPolicyUpdate(year: Int, calendarYear: Int, policyOn: Bool, prismCount: Int, gridChildCountBefore: Int) -> ClimatePolicyPerfSession {
		ClimatePolicyPerfSession()
	}
	
	static func endPolicyUpdate(_ session: ClimatePolicyPerfSession, segments: ClimatePolicyPerfSegments, gridChildCountAfter: Int) {}
}

final class MainThreadHitchMonitor {
	static let shared = MainThreadHitchMonitor()
	func start() {}
	func stop() {}
	func beginWindow(_ label: String, seconds: CFTimeInterval = 3) {}
}

struct ClimatePolicyPerfSegments {}

struct ClimatePolicyPerfSession {}

#endif

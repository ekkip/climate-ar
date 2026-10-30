//
//  MergedPrismLayer.swift
//  ARKitExample
//
//  Draws all globe prisms as one mesh (one draw call instead of one per prism).
//  Mesh and per-cell values for all years are uploaded once; a geometry shader modifier computes every prism's height
//  from the displayed (fractional) year and policy blend, so year changes, scrubbing and animations need no rebuilds.
//

import Foundation
import Metal
import SceneKit
import simd

final class MergedPrismLayer {
	
	struct Shape {
		let baseRadius: Float
		let scaleCorrection: Float
		let threshold: Float
		let widthSocket: Float
		let widthFactor: Float
		let heightFactor: Float
	}
	
	/// Per-cell data in flat arrays; immutable once handed to the layer, so it can be read off the main thread.
	struct Cells {
		private(set) var rotations = [simd_float3x3]()
		private(set) var baseValues = [Float]()
		private(set) var baseStarts = [Int]()
		private(set) var baseCounts = [Int]()
		private(set) var policyValues = [Float]()
		private(set) var policyStarts = [Int]()
		private(set) var policyCounts = [Int]()
		
		var count: Int { return rotations.count }
		
		mutating func reserveCapacity(cells: Int, baseValues baseValueCount: Int, policyValues policyValueCount: Int) {
			rotations.reserveCapacity(cells)
			baseStarts.reserveCapacity(cells)
			baseCounts.reserveCapacity(cells)
			policyStarts.reserveCapacity(cells)
			policyCounts.reserveCapacity(cells)
			baseValues.reserveCapacity(baseValueCount)
			policyValues.reserveCapacity(policyValueCount)
		}
		
		mutating func append(rotation: simd_float3x3, years: [Float], years26: [Float]) {
			rotations.append(rotation)
			baseStarts.append(baseValues.count)
			baseCounts.append(years.count)
			baseValues.append(contentsOf: years)
			policyStarts.append(policyValues.count)
			policyCounts.append(years26.count)
			policyValues.append(contentsOf: years26)
		}
		
		func yearCount(cell i: Int) -> Int {
			return baseCounts[i]
		}
		
		/// First year index of the cell's policy series; equal to `yearCount` when it has none.
		func policyOffset(cell i: Int) -> Int {
			return baseCounts[i] - policyCounts[i]
		}
		
		/// Same selection rule as `Prism.yearValue`; nil when the year is outside the cell's series.
		func value(cell i: Int, year: Int, policy: Bool) -> Float? {
			let baseCount = baseCounts[i]
			guard year < baseCount else { return nil }
			let offset = baseCount - policyCounts[i]
			if policy && year >= offset {
				return policyValues[policyStarts[i] + year - offset]
			}
			return baseValues[baseStarts[i] + year]
		}
	}
	
	private struct Template {
		let positions: [SIMD3<Float>]
		let normals: [SIMD3<Float>]
		let triangleIndices: [Int]
	}
	
	/// Displayed year index (fractional while scrubbing or animating) and policy blend (0 = base, 1 = policy series).
	struct State: Equatable {
		var year: Double
		var policy: Double
	}
	
	static let animationDuration: CFTimeInterval = 0.5
	/// Largest 2D texture size on every Metal GPU family; one texture row per cell.
	private static let maxTextureSize = 16_384
	/// Hidden prisms collapse onto their base, pulled this far inside the globe surface.
	private static let hiddenRadiusFactor: Float = 0.98
	private static let animationKey = "prismState"
	
	/// Each vertex stores its prism's position at value 0 (`position`), the change per unit value (`color.rgb`; prism shape is
	/// linear in the value) and its cell (`texcoords[0].x`). `prismValues` holds one row per cell: the base series in columns
	/// 0...lastYear, then the policy series from year `prismPolicyStart` on (earlier years repeat the base series).
	private static let shaderModifier = """
	#pragma arguments
	texture2d<float> prismValues;
	float prismYear;
	float prismPolicy;
	float prismLastYear;
	float prismPolicyStart;
	float prismThreshold;
	float prismHiddenScale;
	#pragma body
	uint cell = uint(_geometry.texcoords[0].x + 0.5);
	float year = clamp(prismYear, 0.0, prismLastYear);
	uint y0 = uint(year);
	uint y1 = min(y0 + 1, uint(prismLastYear));
	float f = year - float(y0);
	uint baseColumns = uint(prismLastYear) + 1;
	uint policyStart = uint(prismPolicyStart);
	uint p0 = y0 < policyStart ? y0 : baseColumns + y0 - policyStart;
	uint p1 = y1 < policyStart ? y1 : baseColumns + y1 - policyStart;
	float baseValue = mix(prismValues.read(uint2(y0, cell)).r, prismValues.read(uint2(y1, cell)).r, f);
	float policyValue = mix(prismValues.read(uint2(p0, cell)).r, prismValues.read(uint2(p1, cell)).r, f);
	float value = mix(baseValue, policyValue, prismPolicy);
	if (value > prismThreshold) {
		_geometry.position.xyz += value * _geometry.color.rgb;
	} else {
		_geometry.position.xyz *= prismHiddenScale;
	}
	_geometry.color = float4(1.0);
	"""
	
	let node = SCNNode()
	
	/// Called for every displayed state: on the main thread when set directly, on the SceneKit render thread while animating.
	/// Only update SceneKit nodes in it.
	var onStateChanged: ((State) -> Void)?
	
	/// Last year index of the longest cell series; shorter series have value 0 (hidden) beyond their end.
	let lastYear: Int
	let cellCount: Int
	
	private let material: SCNMaterial
	private let stateLock = NSLock()
	private var renderedState = State(year: 0, policy: 0)
	/// Replaced animations are ignored via the generation.
	private var stateGeneration = 0
	
	/// Builds mesh and value texture synchronously (tens of ms in Release); call off the main thread.
	init?(cells: Cells, shape: Shape, templateGeometry: SCNGeometry) {
		guard cells.count > 0, cells.count <= MergedPrismLayer.maxTextureSize,
			let template = MergedPrismLayer.makeTemplate(from: templateGeometry),
			let templateMaterial = templateGeometry.firstMaterial,
			let material = templateMaterial.copy() as? SCNMaterial,
			let device = MTLCreateSystemDefaultDevice() else {
			return nil
		}
		#if DEBUG
		let signpost = GlobePerf.beginMergedBuild(year: 0, policy: false)
		let buildStart = Date()
		#endif
		
		let lastYear = max(0, ((0..<cells.count).map { cells.yearCount(cell: $0) }.max() ?? 1) - 1)
		let policyStart = (0..<cells.count).map { cells.policyOffset(cell: $0) }.min().map { min($0, lastYear + 1) } ?? lastYear + 1
		guard let values = MergedPrismLayer.makeValueTexture(cells: cells, lastYear: lastYear, policyStart: policyStart, device: device) else {
			return nil
		}
		let geometry = MergedPrismLayer.makeGeometry(cells: cells, shape: shape, template: template, maxValues: values.maxValues)
		
		material.shaderModifiers = [.geometry: MergedPrismLayer.shaderModifier]
		material.setValue(SCNMaterialProperty(contents: values.texture), forKey: "prismValues")
		material.setValue(Double(lastYear), forKey: "prismLastYear")
		material.setValue(Double(policyStart), forKey: "prismPolicyStart")
		material.setValue(Double(shape.threshold), forKey: "prismThreshold")
		material.setValue(Double(MergedPrismLayer.hiddenRadiusFactor), forKey: "prismHiddenScale")
		material.setValue(0.0, forKey: "prismYear")
		material.setValue(0.0, forKey: "prismPolicy")
		geometry.materials = [material]
		
		self.material = material
		self.lastYear = lastYear
		self.cellCount = cells.count
		node.name = "Merged prisms"
		node.geometry = geometry
		
		#if DEBUG
		GlobePerf.endMergedBuild(signpost, visible: cells.count)
		GlobePerf.logMergedSetup(
			cells: cells.count, columns: values.columns, buildMs: Date().timeIntervalSince(buildStart) * 1_000,
			vertexMB: Double(cells.count * template.positions.count * MergedPrismLayer.bytesPerVertex) / 1_048_576,
			textureMB: Double(values.columns * cells.count * MemoryLayout<Float>.size) / 1_048_576
		)
		#endif
	}
	
	/// Main thread. Moves the displayed year and policy blend linearly from where they are now; intermediate years are shown on the way.
	func update(year: Int, policy: Bool, duration: CFTimeInterval = MergedPrismLayer.animationDuration, completion: (() -> Void)? = nil) {
		let target = State(year: Double(min(max(year, 0), lastYear)), policy: policy ? 1 : 0)
		let start = readState()
		let generation = restartState()
		if duration <= 0 || start == target {
			apply(target, generation: generation)
		} else {
			let advance = SCNAction.customAction(duration: duration) { [weak self] _, elapsed in
				let t = min(1, Double(elapsed) / duration)
				let state = State(
					year: start.year + (target.year - start.year) * t,
					policy: start.policy + (target.policy - start.policy) * t
				)
				self?.apply(state, generation: generation)
			}
			let finish = SCNAction.run { [weak self] _ in self?.apply(target, generation: generation) }
			node.runAction(.sequence([advance, finish]), forKey: MergedPrismLayer.animationKey)
		}
		completion?()
	}
	
	/// Main thread, once per scroll step: shows a fractional year index directly, stopping any animation.
	func scrub(to year: Double, policy: Bool) {
		let generation = restartState()
		apply(State(year: min(max(year, 0), Double(lastYear)), policy: policy ? 1 : 0), generation: generation)
	}
	
	// MARK: - Displayed state
	
	private func restartState() -> Int {
		node.removeAction(forKey: MergedPrismLayer.animationKey)
		stateLock.lock()
		stateGeneration += 1
		let generation = stateGeneration
		stateLock.unlock()
		return generation
	}
	
	private func apply(_ state: State, generation: Int) {
		stateLock.lock()
		guard generation == stateGeneration else {
			stateLock.unlock()
			return
		}
		renderedState = state
		stateLock.unlock()
		material.setValue(state.year, forKey: "prismYear")
		material.setValue(state.policy, forKey: "prismPolicy")
		onStateChanged?(state)
	}
	
	private func readState() -> State {
		stateLock.lock()
		defer { stateLock.unlock() }
		return renderedState
	}
	
	// MARK: - Static data
	
	/// Position (float3), growth per unit value (float3), normal (float3), cell index (float2).
	private static let bytesPerVertex = 11 * MemoryLayout<Float>.size
	
	private static func makeValueTexture(cells: Cells, lastYear: Int, policyStart: Int, device: MTLDevice) -> (texture: MTLTexture, columns: Int, maxValues: [Float])? {
		let baseColumns = lastYear + 1
		let columns = baseColumns + (baseColumns - policyStart)
		guard columns <= maxTextureSize else { return nil }
		var values = [Float](repeating: 0, count: columns * cells.count)
		var maxValues = [Float](repeating: 0, count: cells.count)
		for i in 0..<cells.count {
			let row = i * columns
			var maxValue: Float = 0
			for year in 0..<min(cells.yearCount(cell: i), baseColumns) {
				let base = cells.value(cell: i, year: year, policy: false) ?? 0
				values[row + year] = base
				maxValue = max(maxValue, base)
				if year >= policyStart {
					let policy = cells.value(cell: i, year: year, policy: true) ?? 0
					values[row + baseColumns + year - policyStart] = policy
					maxValue = max(maxValue, policy)
				}
			}
			maxValues[i] = maxValue
		}
		
		let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .r32Float, width: columns, height: cells.count, mipmapped: false)
		descriptor.usage = .shaderRead
		guard let texture = device.makeTexture(descriptor: descriptor) else { return nil }
		values.withUnsafeBytes { raw in
			texture.replace(
				region: MTLRegionMake2D(0, 0, columns, cells.count), mipmapLevel: 0,
				withBytes: raw.baseAddress!, bytesPerRow: columns * MemoryLayout<Float>.size
			)
		}
		return (texture, columns, maxValues)
	}
	
	private static func makeGeometry(cells: Cells, shape: Shape, template: Template, maxValues: [Float]) -> SCNGeometry {
		let verticesPerCell = template.positions.count
		let vertexCount = cells.count * verticesPerCell
		var positions = [Float](repeating: 0, count: vertexCount * 3)
		var growths = [Float](repeating: 0, count: vertexCount * 3)
		var normals = [Float](repeating: 0, count: vertexCount * 3)
		var cellIndices = [Float](repeating: 0, count: vertexCount * 2)
		
		let c = shape.scaleCorrection
		let baseScale = SIMD3<Float>(shape.widthSocket, 0, shape.widthSocket) * c
		let baseTranslation = SIMD3<Float>(0, shape.baseRadius, 0)
		let growthScale = SIMD3<Float>(shape.widthFactor, shape.heightFactor, shape.widthFactor) * c
		let growthTranslation = SIMD3<Float>(0, 0.5 * shape.heightFactor, 0)
		// Normals do not depend on the value (vertical sides, flat caps); prisms of this value are about as tall as wide.
		let normalReferenceValue: Float = 15
		let normalScale = baseScale + normalReferenceValue * growthScale
		var lower = SIMD3<Float>(repeating: .greatestFiniteMagnitude)
		var upper = SIMD3<Float>(repeating: -.greatestFiniteMagnitude)
		
		for i in 0..<cells.count {
			let rotation = cells.rotations[i]
			var o3 = i * verticesPerCell * 3
			var o2 = i * verticesPerCell * 2
			for k in 0..<verticesPerCell {
				let t = template.positions[k]
				let a = rotation * (t * baseScale + baseTranslation)
				let b = rotation * (t * growthScale + growthTranslation)
				let n = simd_normalize(rotation * (template.normals[k] / normalScale))
				let top = a + maxValues[i] * b
				lower = simd_min(lower, simd_min(a, top))
				upper = simd_max(upper, simd_max(a, top))
				positions[o3] = a.x; positions[o3 + 1] = a.y; positions[o3 + 2] = a.z
				growths[o3] = b.x; growths[o3 + 1] = b.y; growths[o3 + 2] = b.z
				normals[o3] = n.x; normals[o3 + 1] = n.y; normals[o3 + 2] = n.z
				cellIndices[o2] = Float(i)
				o3 += 3
				o2 += 2
			}
		}
		
		let geometry = SCNGeometry(
			sources: [
				makeSource(positions, semantic: .vertex, components: 3),
				makeSource(normals, semantic: .normal, components: 3),
				makeSource(growths, semantic: .color, components: 3),
				makeSource(cellIndices, semantic: .texcoord, components: 2)
			],
			elements: [makeElement(cellCount: cells.count, template: template)]
		)
		// Bounds come from the static positions otherwise, which would let SceneKit cull tall prisms.
		geometry.boundingBox = (SCNVector3(lower), SCNVector3(upper))
		return geometry
	}
	
	private static func makeSource(_ values: [Float], semantic: SCNGeometrySource.Semantic, components: Int) -> SCNGeometrySource {
		return SCNGeometrySource(
			data: values.withUnsafeBufferPointer { Data(buffer: $0) }, semantic: semantic,
			vectorCount: values.count / components,
			usesFloatComponents: true, componentsPerVector: components,
			bytesPerComponent: MemoryLayout<Float>.size,
			dataOffset: 0, dataStride: components * MemoryLayout<Float>.size
		)
	}
	
	private static func makeElement(cellCount: Int, template: Template) -> SCNGeometryElement {
		let verticesPerCell = template.positions.count
		var indices = [UInt32]()
		indices.reserveCapacity(cellCount * template.triangleIndices.count)
		for i in 0..<cellCount {
			let base = i * verticesPerCell
			for index in template.triangleIndices {
				indices.append(UInt32(base + index))
			}
		}
		let data = indices.withUnsafeBufferPointer { Data(buffer: $0) }
		return SCNGeometryElement(
			data: data, primitiveType: .triangles,
			primitiveCount: indices.count / 3,
			bytesPerIndex: MemoryLayout<UInt32>.size
		)
	}
	
	// MARK: - Template extraction
	
	private static func makeTemplate(from geometry: SCNGeometry) -> Template? {
		guard let vertexSource = geometry.sources(for: .vertex).first,
			let normalSource = geometry.sources(for: .normal).first,
			let positions = readVectors(vertexSource),
			let normals = readVectors(normalSource),
			positions.count == normals.count else {
			return nil
		}
		var triangleIndices = [Int]()
		for element in geometry.elements {
			guard let triangles = triangulate(element) else { return nil }
			triangleIndices += triangles
		}
		return Template(positions: positions, normals: normals, triangleIndices: triangleIndices)
	}
	
	private static func readVectors(_ source: SCNGeometrySource) -> [SIMD3<Float>]? {
		guard source.usesFloatComponents, source.bytesPerComponent == 4, source.componentsPerVector >= 3 else { return nil }
		return source.data.withUnsafeBytes { (raw: UnsafeRawBufferPointer) -> [SIMD3<Float>] in
			(0..<source.vectorCount).map { i in
				let base = source.dataOffset + i * source.dataStride
				return SIMD3<Float>(
					raw.loadUnaligned(fromByteOffset: base, as: Float.self),
					raw.loadUnaligned(fromByteOffset: base + 4, as: Float.self),
					raw.loadUnaligned(fromByteOffset: base + 8, as: Float.self)
				)
			}
		}
	}
	
	private static func readIndex(_ raw: UnsafeRawBufferPointer, _ i: Int, bytesPerIndex: Int) -> Int {
		switch bytesPerIndex {
		case 1: return Int(raw[i])
		case 2: return Int(raw.loadUnaligned(fromByteOffset: i * 2, as: UInt16.self))
		default: return Int(raw.loadUnaligned(fromByteOffset: i * 4, as: UInt32.self))
		}
	}
	
	/// Polygon elements store all per-polygon vertex counts first, then the indices; polygons are fan-triangulated.
	private static func triangulate(_ element: SCNGeometryElement) -> [Int]? {
		let bpi = element.bytesPerIndex
		let primitiveCount = element.primitiveCount
		return element.data.withUnsafeBytes { (raw: UnsafeRawBufferPointer) -> [Int]? in
			var out = [Int]()
			switch element.primitiveType {
			case .triangles:
				for i in 0..<(primitiveCount * 3) {
					out.append(readIndex(raw, i, bytesPerIndex: bpi))
				}
			case .polygon:
				var cursor = primitiveCount
				for p in 0..<primitiveCount {
					let n = readIndex(raw, p, bytesPerIndex: bpi)
					let first = readIndex(raw, cursor, bytesPerIndex: bpi)
					if n >= 3 {
						for k in 1..<(n - 1) {
							out.append(first)
							out.append(readIndex(raw, cursor + k, bytesPerIndex: bpi))
							out.append(readIndex(raw, cursor + k + 1, bytesPerIndex: bpi))
						}
					}
					cursor += n
				}
			default:
				return nil
			}
			return out
		}
	}
	
	static func rotation(of node: SCNNode) -> simd_float3x3 {
		let m = node.simdTransform
		return simd_float3x3(
			SIMD3<Float>(m.columns.0.x, m.columns.0.y, m.columns.0.z),
			SIMD3<Float>(m.columns.1.x, m.columns.1.y, m.columns.1.z),
			SIMD3<Float>(m.columns.2.x, m.columns.2.y, m.columns.2.z)
		)
	}
}

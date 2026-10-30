//
//  MergedPrismLayer.swift
//  ARKitExample
//
//  Draws all globe prisms as one mesh (one draw call instead of one per prism).
//  Vertex data is rebuilt on a background queue; the main thread only swaps in the finished geometry.
//

import Foundation
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
	
	let node = SCNNode()
	
	/// Called on the main thread right after a new geometry has been swapped in.
	var onApplied: ((_ year: Int, _ policy: Bool) -> Void)?
	
	private let cells: Cells
	private let shape: Shape
	private let template: Template
	private let element: SCNGeometryElement
	private let material: SCNMaterial
	private let queue = DispatchQueue(label: "globe.mergedPrismLayer", qos: .userInitiated)
	
	private var isBuilding = false
	private var pendingRequest: (year: Int, policy: Bool)?
	private var pendingCompletions = [() -> Void]()
	private var coalescedRequests = 0
	
	var cellCount: Int { return cells.count }
	
	init?(cells: Cells, shape: Shape, templateGeometry: SCNGeometry) {
		guard let template = MergedPrismLayer.makeTemplate(from: templateGeometry),
			let material = templateGeometry.firstMaterial else {
			return nil
		}
		self.cells = cells
		self.shape = shape
		self.template = template
		self.material = material
		self.element = MergedPrismLayer.makeElement(cellCount: cells.count, template: template)
		node.name = "Merged prisms"
		node.movabilityHint = .movable
	}
	
	/// Main thread only. Requests arriving while a build runs are coalesced to the latest one.
	func update(year: Int, policy: Bool, completion: (() -> Void)? = nil) {
		if let completion = completion {
			pendingCompletions.append(completion)
		}
		if isBuilding {
			if pendingRequest != nil {
				coalescedRequests += 1
			}
			pendingRequest = (year, policy)
			return
		}
		startBuild(year: year, policy: policy)
	}
	
	private func startBuild(year: Int, policy: Bool) {
		isBuilding = true
		let completions = pendingCompletions
		pendingCompletions = []
		let coalesced = coalescedRequests
		coalescedRequests = 0
		let requested = Date()
		
		let cells = self.cells
		let shape = self.shape
		let template = self.template
		let element = self.element
		let material = self.material
		
		queue.async { [weak self] in
			#if DEBUG
			let signpost = GlobePerf.beginMergedBuild(year: year, policy: policy)
			#endif
			let buildStart = Date()
			let vertices = MergedPrismLayer.buildVertices(
				year: year, policy: policy, cells: cells, shape: shape, template: template
			)
			let visibleCount = vertices.visibleCount
			let buildMs = Date().timeIntervalSince(buildStart) * 1_000
			#if DEBUG
			GlobePerf.endMergedBuild(signpost, visible: visibleCount)
			#endif
			
			DispatchQueue.main.async {
				guard let self = self else { return }
				let applyStart = Date()
				// SceneKit objects are created here: the shared material is also used by the render thread.
				let geometry = MergedPrismLayer.makeGeometry(vertices, element: element, material: material)
				SCNTransaction.begin()
				SCNTransaction.animationDuration = 0
				self.node.geometry = geometry
				SCNTransaction.commit()
				self.onApplied?(year, policy)
				let applyMs = Date().timeIntervalSince(applyStart) * 1_000
				
				#if DEBUG
				GlobePerf.logMergedUpdate(
					year: year, policy: policy, cells: cells.count, visible: visibleCount,
					queueWaitMs: buildStart.timeIntervalSince(requested) * 1_000,
					buildMs: buildMs, applyMs: applyMs,
					totalMs: Date().timeIntervalSince(requested) * 1_000,
					coalesced: coalesced
				)
				#endif
				
				self.isBuilding = false
				completions.forEach { $0() }
				if let next = self.pendingRequest {
					self.pendingRequest = nil
					self.startBuild(year: next.year, policy: next.policy)
				}
			}
		}
	}
	
	// MARK: - Geometry
	
	private struct Vertices {
		let positions: Data
		let normals: Data
		let vertexCount: Int
		let visibleCount: Int
	}
	
	private static func makeGeometry(_ vertices: Vertices, element: SCNGeometryElement, material: SCNMaterial) -> SCNGeometry {
		let positionSource = makeSource(vertices.positions, semantic: .vertex, vectorCount: vertices.vertexCount)
		let normalSource = makeSource(vertices.normals, semantic: .normal, vectorCount: vertices.vertexCount)
		let geometry = SCNGeometry(sources: [positionSource, normalSource], elements: [element])
		geometry.materials = [material]
		return geometry
	}
	
	private static func buildVertices(year: Int, policy: Bool, cells: Cells, shape: Shape, template: Template) -> Vertices {
		let verticesPerCell = template.positions.count
		let vertexCount = cells.count * verticesPerCell
		var positions = [Float](repeating: 0, count: vertexCount * 3)
		var normals = [Float](repeating: 0, count: vertexCount * 3)
		var visibleCount = 0
		
		positions.withUnsafeMutableBufferPointer { pos in
			normals.withUnsafeMutableBufferPointer { nor in
				template.positions.withUnsafeBufferPointer { templatePositions in
					template.normals.withUnsafeBufferPointer { templateNormals in
						for i in 0..<cells.count {
							// Hidden cells keep zeroed vertices, i.e. degenerate triangles that rasterize nothing.
							guard let value = cells.value(cell: i, year: year, policy: policy), value > shape.threshold else { continue }
							visibleCount += 1
							
							let height = value * shape.heightFactor
							let width = shape.widthSocket + value * shape.widthFactor
							let scale = SIMD3<Float>(width, height, width) * shape.scaleCorrection
							let translation = SIMD3<Float>(0, shape.baseRadius + 0.5 * height, 0)
							let rotation = cells.rotations[i]
							
							var offset = i * verticesPerCell * 3
							for k in 0..<verticesPerCell {
								let p = rotation * (templatePositions[k] * scale + translation)
								let n = simd_normalize(rotation * (templateNormals[k] / scale))
								pos[offset] = p.x
								pos[offset + 1] = p.y
								pos[offset + 2] = p.z
								nor[offset] = n.x
								nor[offset + 1] = n.y
								nor[offset + 2] = n.z
								offset += 3
							}
						}
					}
				}
			}
		}
		
		return Vertices(
			positions: positions.withUnsafeBufferPointer { Data(buffer: $0) },
			normals: normals.withUnsafeBufferPointer { Data(buffer: $0) },
			vertexCount: vertexCount,
			visibleCount: visibleCount
		)
	}
	
	private static func makeSource(_ data: Data, semantic: SCNGeometrySource.Semantic, vectorCount: Int) -> SCNGeometrySource {
		return SCNGeometrySource(
			data: data, semantic: semantic, vectorCount: vectorCount,
			usesFloatComponents: true, componentsPerVector: 3,
			bytesPerComponent: MemoryLayout<Float>.size,
			dataOffset: 0, dataStride: 3 * MemoryLayout<Float>.size
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

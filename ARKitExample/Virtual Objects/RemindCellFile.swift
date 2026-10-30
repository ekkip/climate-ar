//
//  RemindCellFile.swift
//  ARKitExample
//
//  Reader for REMIND_cells.bin, generated from the REMIND JSON grids by Scripts/convert_remind_json.py.
//

import Foundation

enum RemindCellFile {
	
	struct Cell {
		let lon: Int
		let lat: Int
		let years: [Float]
		let years26: [Float]
	}
	
	private static let magic: [UInt8] = Array("RMD1".utf8)
	
	struct Summary {
		let cellCount: Int
	}
	
	/// Calls `body` once per cell; returns nil if the file is missing or malformed.
	static func read(resource: String = "REMIND_cells", body: (Cell) -> Void) -> Summary? {
		guard let url = Bundle.main.url(forResource: resource, withExtension: "bin"),
			let data = try? Data(contentsOf: url, options: .alwaysMapped) else {
			return nil
		}
		return data.withUnsafeBytes { (raw: UnsafeRawBufferPointer) -> Summary? in
			guard raw.count >= 8, Array(raw[0..<4]) == magic else { return nil }
			let cellCount = Int(raw.loadUnaligned(fromByteOffset: 4, as: UInt32.self))
			var offset = 8
			for _ in 0..<cellCount {
				guard offset + 8 <= raw.count else { return nil }
				let lon = Int(raw.loadUnaligned(fromByteOffset: offset, as: UInt16.self))
				let lat = Int(raw.loadUnaligned(fromByteOffset: offset + 2, as: UInt16.self))
				let baseCount = Int(raw.loadUnaligned(fromByteOffset: offset + 4, as: UInt16.self))
				let policyCount = Int(raw.loadUnaligned(fromByteOffset: offset + 6, as: UInt16.self))
				offset += 8
				let byteCount = (baseCount + policyCount) * MemoryLayout<Float>.size
				guard offset + byteCount <= raw.count else { return nil }
				let years = floats(raw, offset: offset, count: baseCount)
				let years26 = floats(raw, offset: offset + baseCount * MemoryLayout<Float>.size, count: policyCount)
				offset += byteCount
				body(Cell(lon: lon, lat: lat, years: years, years26: years26))
			}
			return Summary(cellCount: cellCount)
		}
	}
	
	private static func floats(_ raw: UnsafeRawBufferPointer, offset: Int, count: Int) -> [Float] {
		return [Float](unsafeUninitializedCapacity: count) { buffer, initialized in
			memcpy(buffer.baseAddress!, raw.baseAddress! + offset, count * MemoryLayout<Float>.size)
			initialized = count
		}
	}
}

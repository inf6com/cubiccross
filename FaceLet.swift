//
//  FaceLet.swift
//  CubicCross
//
//  Created by decopin on 2025/03/29.
//

import Foundation
import SwiftUI

public enum CubeFace: String {
    case front, back, left, right, top, bottom
}

public struct GridPosition {
    let x: Int
    let y: Int
}

public struct Pos3D: Hashable {
    let x: Int
    let y: Int
    let z: Int
}

public struct Facelet: Identifiable {
    public var id: String {
        "\(face.rawValue)_\(i)_\(j)"
    }

    let face: CubeFace
    let i: Int
    let j: Int
    let grid: GridPosition
    let pos3D: Pos3D
}

public struct Cell {
    var color: Color
    var facelet: Facelet
}

public struct CellFactory {
    static func generateCells(facelets: [Facelet]) -> [Cell] {
        return facelets.map { facelet in
            Cell(color: .gray, facelet: facelet) // デフォルトはグレー、必要に応じて色を変更
        }
    }
}

let allFacelets: [Facelet] = {
    var array = [Facelet]()
    
    // --- Top face ---
    // 仮定: Top face  pos3D: (i, 0, j), grid: (6 + i, 0 + j)
    for i in 0..<6 {
        for j in 0..<6 {
            array.append(Facelet(
                face: .top,
                i: i,
                j: j,
                grid: GridPosition(x: 6 + i, y: 0 + j),
                pos3D: Pos3D(x: i, y: 0, z: j)
            ))
        }
    }
    
    // --- Front face ---
    // 仮定: Front face  pos3D: (i, j, 5), grid: (6 + i, 28 + j)
    for i in 0..<6 {
        for j in 0..<6 {
            array.append(Facelet(
                face: .front,
                i: i,
                j: j,
                grid: GridPosition(x: 6 + i, y: 28 + j),
                pos3D: Pos3D(x: i, y: j, z: 5)
            ))
        }
    }
    
    // --- Right face ---
    // 仮定: Right face  pos3D: (5, i, j), grid: (18 + j, 22 + i)
    for i in 0..<6 {
        for j in 0..<6 {
            array.append(Facelet(
                face: .right,
                i: i,
                j: j,
                grid: GridPosition(x: 18 + j, y: 22 + i),
                pos3D: Pos3D(x: 5, y: i, z: j)
            ))
        }
    }
    
    // --- Bottom face ---
    // 仮定: Bottom face  pos3D: (i, 5, j), grid: (6 + i, 46 + j)
    for i in 0..<6 {
        for j in 0..<6 {
            array.append(Facelet(
                face: .bottom,
                i: i,
                j: j,
                grid: GridPosition(x: 6 + i, y: 46 + j),
                pos3D: Pos3D(x: i, y: 5, z: j)
            ))
        }
    }
    
    // --- Left face ---
    // 仮定: Left face  pos3D: (0, i, j), grid: (0 + j, 22 + i)
    for i in 0..<6 {
        for j in 0..<6 {
            array.append(Facelet(
                face: .left,
                i: i,
                j: j,
                grid: GridPosition(x: j, y: 22 + i),
                pos3D: Pos3D(x: 0, y: i, z: j)
            ))
        }
    }
    
    // --- Back face ---
    // 仮定: Back face  pos3D: (i, j, 0), grid: (6 + i, 34 + j)
    for i in 0..<6 {
        for j in 0..<6 {
            array.append(Facelet(
                face: .back,
                i: i,
                j: j,
                grid: GridPosition(x: 6 + i, y: 34 + j),
                pos3D: Pos3D(x: i, y: j, z: 0)
            ))
        }
    }
    
    return array
}()

public enum Axis3D {
    case x, y, z
}

public func determineFixedAxis(face: CubeFace, isHorizontal: Bool) -> Axis3D {
    switch face {
    case .top, .bottom, .front, .back:
        return isHorizontal ? .y : .x
    case .left, .right:
        return isHorizontal ? .z : .y
    }
}

public func sliceIndex(from facelet: Facelet, axis: Axis3D) -> Int {
    switch axis {
    case .x: return facelet.pos3D.x
    case .y: return facelet.pos3D.y
    case .z: return facelet.pos3D.z
    }
}

public func isFaceAffected(face: CubeFace, by axis: Axis3D) -> Bool {
    switch axis {
    case .x: return face != .right && face != .left
    case .y: return face != .top && face != .bottom
    case .z: return face != .front && face != .back
    }
}

public func targetFaceletsForSlice(from facelet: Facelet, isHorizontal: Bool) -> [Facelet] {
    let axis = determineFixedAxis(face: facelet.face, isHorizontal: isHorizontal)
    let index = sliceIndex(from: facelet, axis: axis)
    return allFacelets.filter {
        sliceIndex(from: $0, axis: axis) == index && isFaceAffected(face: $0.face, by: axis)
    }
}

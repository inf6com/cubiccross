// MARK: - CubeFace Grid Origin Utility
func getFaceOrigin(for face: CubeFace) -> (originX: Int, originY: Int) {
    switch face {
    case .left:
        return (originX: 0, originY: 22)
    case .front:
        return (originX: 6, originY: 22)
    case .right:
        return (originX: 12, originY: 22)
    case .bottom:
        return (originX: 6, originY: 28)
    case .back:
        return (originX: 6, originY: 34)
    case .top:
        return (originX: 6, originY: 40)
    }
}

// MARK: - Pos3D to Facelet Mapping
func pos3DToFacelet(_ pos: Pos3D) -> Facelet? {
    let face: CubeFace
    let i, j: Int
    switch (pos.x, pos.y, pos.z) {
    case let (0, y, z):
        face = .left
        i = 5 - z
        j = y
    case let (5, y, z):
        face = .right
        i = z
        j = y
    case let (x, 0, z):
        face = .top
        i = x
        j = z
    case let (x, 5, z):
        face = .bottom
        i = x
        j = z
    case let (x, y, 1):
        face = .front
        i = x
        j = y
    case let (x, y, 4):
        face = .back
        i = x
        j = y
    default:
        return nil
    }

    let faceOrigin = getFaceOrigin(for: face)
    let grid = GridPosition(x: faceOrigin.originX + i, y: faceOrigin.originY + j)
    return Facelet(face: face, i: i, j: j, grid: grid, pos3D: pos)
}
//
//  MainContainerView.swift
//  CubicCross
//
//  Created by decopin on 2025/05/09.
//


import Foundation
import SwiftUI

extension Color {
    var name: String {
        switch self {
        case .red: return "red"
        case .blue: return "blue"
        case .green: return "green"
        case .yellow: return "yellow"
        case .orange: return "orange"
        case .white: return "white"
        default: return "unknown"
        }
    }
}
import AVFoundation
import UIKit
import UniformTypeIdentifiers
import MusicKit
import simd
import CoreGraphics
import GoogleMobileAds
import CoreML


/// Wrapper for RedSpecial’s SwitchViewModel to be used as an EnvironmentObject
class RedSpecialWrapper: ObservableObject {
    @Published var model: SwitchViewModel

    init(model: SwitchViewModel) {
        self.model = model
    }
}

// MARK: - SwitchViewModel PCM Buffer Property and Methods
// Moved into SwitchViewModel class definition (see SwitchViewModel.swift)
let N = 6  // Cube size


// MARK: - SwitchViewModel PCM Buffer Property (for holding PCM data)
// Move the buffer property into SwitchViewModel class itself.

// --- Add buffer property to SwitchViewModel ---
// SwitchViewModel is defined elsewhere in the project; do not redefine here.
 

extension Notification.Name {
    static let updateCubeCellsView = Notification.Name("updateCubeCellsView")
}

struct AboutView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text(LocalizedStringKey("About This App"))
                    .font(.title2)
                    .bold()
                Text(LocalizedStringKey("This app uses audio samples from Google's NSynth project."))
                Text(LocalizedStringKey("These samples are licensed under the Creative Commons Attribution 4.0 International License (CC BY 4.0)."))
                Text("このアプリでは Google の NSynth を使用した音源を利用しています。")
                Text("これらの音源は Creative Commons 表示 4.0 国際ライセンス（CC BY 4.0）に基づいて利用しています。")
                Link("ライセンスの詳細はこちら", destination: URL(string: "https://creativecommons.org/licenses/by/4.0/")!)
            }
            .padding()
        }
        .navigationTitle("About")
    }
}




struct AdMobBannerView: UIViewRepresentable {
    let adUnitID: String
    // Specify the UIView type this representable wraps
    typealias UIViewType = BannerView

    func makeUIView(context: Context) -> BannerView {
        #if targetEnvironment(simulator)
        // Return an empty BannerView in simulator
        return BannerView()
        #else
        let banner = BannerView(adSize: currentOrientationAnchoredAdaptiveBanner(width: UIScreen.main.bounds.width))
        banner.adUnitID = adUnitID
        print("📡 Loading AdMob banner with unitID: \(adUnitID)")
        banner.rootViewController = (UIApplication.shared.connectedScenes.first as? UIWindowScene)?.windows.first?.rootViewController
        banner.load(Request())
        return banner
        #endif
    }

    func updateUIView(_ uiView: BannerView, context: Context) {
       // No update needed
    }
}


// MARK: - FaceLetPosition PreferenceKey
struct FaceLetPositionPreferenceKey: PreferenceKey {
    typealias Value = [String: Anchor<CGRect>]

    static var defaultValue: [String: Anchor<CGRect>] = [:]

    static func reduce(value: inout [String: Anchor<CGRect>], nextValue: () -> [String: Anchor<CGRect>]) {
        value.merge(nextValue(), uniquingKeysWith: { $1 })
    }
}


// Revised Pos3D conversion function
func convertToPos3D(from string: String) -> Pos3D? {
    let components = string.split(separator: "_")
    guard components.count >= 3,
          let x = Int(components[components.count - 3]),
          let y = Int(components[components.count - 2]),
          let z = Int(components[components.count - 1]) else {
        return nil
    }

    return Pos3D(x: x, y: y, z: z)
}

extension MappingEntryID {
    var key: String {
        return String(describing: self)
    }
}
// Tested: The code runs without errors. No error messages were encountered during execution.


// MARK: - ContentView
// MARK: - Move struct for cube move history
struct Move {
    let axis: Axis3D
    let sliceIndex: Int
    let clockwise: Bool
    let movedCells: [Pos3D]
    let timestamp: Date
    let swipeVelocity: CGFloat  // スワイプ速度の magnitude（テンポ算出用）
}

struct MainContainerView: View {
    @EnvironmentObject var redSpecial: RedSpecialWrapper
    @StateObject var model: CubicModel
    @StateObject var mappingModel: MappingModel
    @StateObject var soundVM: SwitchViewModel
    @StateObject var elementModel: ElementModel
    @ObservedObject var musicManager = MusicManager.shared
    @State var fretDouble: Double = 10.0
    @State private var selectedFretIndex: Int = 10
    @State private var faceletPositions: [String: Anchor<CGRect>] = [:]
    @State private var cubeCellsDictionary: [String: CubeCell] = [:]
    // Track selected cell(s) and SCAT symbol
    @State private var selectedCellIDs: Set<String> = []
    @State private var selectedScatSymbol: String? = nil
    @State private var moveHistory: [Move] = []
    @State private var nextButtonFlashRed = false
    @State private var prevButtonFlashRed = false

    @State private var colorMatrix: [[String]] = Array(
        repeating: Array(repeating: "unknown", count: 18), count: 6
    )


    init() {
        let element = ElementModel()
        let model = CubicModel()
        let mappingModelInstance = MappingModel(cubicModel: model)
        mappingModelInstance.generateMapping()
        print("🧪 ContentView - model.cubeCells.count (\(model.cubeCells.count))")
        print("🧪 MappingModel entries count: \(mappingModelInstance.entries.count)")


        _model = StateObject(wrappedValue: model)
        _mappingModel = StateObject(wrappedValue: mappingModelInstance)
        _soundVM = StateObject(wrappedValue: SwitchViewModel(cubeVM: model, mappingModel: mappingModelInstance))
        _elementModel = StateObject(wrappedValue: element)
        }
    
    func updateCubeCellsDictionaryFromModel() {
        var updatedDict: [String: CubeCell] = [:]
    for cell in model.cubeCells {
        let grid = cell.facelet.grid
        let key = "\(grid.x)-\(grid.y)"  // To String
        updatedDict[key] = cell
    }
        cubeCellsDictionary = updatedDict
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            GeometryReader { geometry in
                contentBody(geometry: geometry)
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .onReceive(model.objectWillChange) { _ in
            updateCubeCellsDictionaryFromModel()
        }
        .onReceive(NotificationCenter.default.publisher(for: .updateCubeCellsView)) { _ in
            updateCubeCellsDictionaryFromModel()
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("PrevButtonFlashRed"))) { _ in
            print("🔴 PrevButton Flash Triggered")
            prevButtonFlashRed = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                prevButtonFlashRed = false
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("NextButtonFlashRed"))) { _ in
            print("🔴 NextButton Flash Triggered")
            nextButtonFlashRed = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                nextButtonFlashRed = false
            }
        }
        .onAppear {
            DispatchQueue.main.async {
                // showActionSheet() // ← Disabled this popup to avoid alert on launch
            }
        }
    }
    
    private func contentBody(geometry: GeometryProxy) -> AnyView {
        let insets = geometry.safeAreaInsets
        let availableWidth = geometry.size.width - insets.leading - insets.trailing
        let bannerHeight: CGFloat = 90
        let totalUsableHeight = geometry.size.height - bannerHeight

        let allGrids = model.cubeCells.map { $0.facelet.grid.toArray() } + elementModel.elements.map { $0.grid }
        let maxX = allGrids.map { $0[0] + $0[2] }.max() ?? 1
        let maxY = allGrids.map { $0[1] + $0[3] }.max() ?? 1

        let cellWidth = availableWidth / CGFloat(maxX)
        let visualMaxY = CGFloat(maxY)
        let cellHeight = totalUsableHeight / visualMaxY
        let gridSize = (cellWidth: cellWidth, cellHeight: cellHeight)

        // Only C4, C5, C6 faces (z layers 3, 4, 5), sorted by grid Y then X
        let gridsArray = mappingModel.cubicModel.grids
            .filter { [3, 4, 5].contains($0.id.pos3D.z) }
            .sorted {
                let g1 = $0.grid, g2 = $1.grid
                if g1[1] != g2[1] { return g1[1] < g2[1] }
                return g1[0] < g2[0]
            }

        let innerView = ZStack {
            VStack(spacing: 0) {
                Group {
                    #if targetEnvironment(simulator)
                    Color.clear.frame(height: 90)
                    #else
                    AdMobBannerView(adUnitID: Bundle.main.object(forInfoDictionaryKey: "GADBannerAdUnitID") as? String ?? "")
                        .frame(height: 90)
                        .frame(maxWidth: .infinity)
                        .background(Color.black)
                    #endif
                }
                GeometryReader { geometry in
                    VStack(spacing: 0) {
                        ZStack(alignment: .topLeading) {
                            Color.black.ignoresSafeArea()
                            gestureLayer(gridSize: gridSize)

                            // Begin colorMatrix update block
                            ForEach(gridsArray) { entry in
                                EmptyView()
                                    .onAppear {
                                        let grid = entry.grid
                                        if let cell = model.cubeCells.first(where: {
                                            $0.facelet.grid.x == grid[0] && $0.facelet.grid.y == grid[1]
                                        }) {
                                            let colorName = cell.colorName
                                            colorMatrix[grid[1]][grid[0]] = colorName
                                        }
                                    }
                            }
                            // End colorMatrix update block

                            ForEach(model.cubeCells.indices, id: \.self) { index in
                                let cell = model.cubeCells[index]
                                let gridPos = cell.facelet.grid
                                let matchingElement = elementModel.elements.first { $0.grid[0] == gridPos.x && $0.grid[1] == gridPos.y }
                                UnifiedCubeCellView(
                                    cell: cell,
                                    element: matchingElement,
                                    gridSize: gridSize,
                                    soundVM: soundVM,
                                    selectedCellIDs: $selectedCellIDs,
                                    selectedScatSymbol: $selectedScatSymbol
                                )
                                .id(cell.facelet.pos3D.toKey())
                            }

                            elementModelLayer(gridSize: gridSize)
                        }
                        // Add Undo button overlay for testing
                        Button(action: {
                            playAndUndo()
                        }) {
                            Text("Undo")
                                .foregroundColor(.white)
                                .padding()
                                .background(Color.red)
                                .cornerRadius(8)
                        }
                        .zIndex(999)
                        .padding(.top, 16)
                        .padding(.leading, 16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
        let configuredView = innerView
            .onPreferenceChange(FaceLetPositionPreferenceKey.self) { value in
                faceletPositions = value
            }
            .frame(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)
        return AnyView(configuredView)
    }
    
    private func gestureCellView(id: String, i: Int, j: Int, z: Int, gridSize: (cellWidth: CGFloat, cellHeight: CGFloat)) -> AnyView {
        guard let faceLayout = GridConfig.faceLayouts.first(where: { $0.fixed == z }) else {
            return AnyView(EmptyView())
        }
        let gridX = faceLayout.originX + i
        let gridY = faceLayout.originY + j
        let offsetX = CGFloat(gridX) * gridSize.cellWidth
        let offsetY = CGFloat(gridY) * gridSize.cellHeight

        let dragGesture = DragGesture(minimumDistance: 10)
            .onEnded { value in
                let vel = value.velocity  // CGSize (iOS 17+)
                let swipePoint = CGPoint(x: vel.width, y: vel.height)
                soundVM.handleInteraction(for: "\(id)_\(i)_\(j)", translation: value.translation, swipeVelocity: swipePoint)
            }

        let view = Color.clear
            .contentShape(Rectangle())
            .frame(width: gridSize.cellWidth, height: gridSize.cellHeight)
            .position(x: offsetX + gridSize.cellWidth / 2, y: offsetY + gridSize.cellHeight / 2)
            .simultaneousGesture(dragGesture)
            .zIndex(200)

        return AnyView(view)
    }
    
    @ViewBuilder
    private func gestureLayer(gridSize: (cellWidth: CGFloat, cellHeight: CGFloat)) -> some View {
        ForEach(["P1", "P2", "P3"], id: \.self) { id in
            let zIndexMap: [String: Int] = ["P1": 3, "P2": 4, "P3": 5]
            let z = zIndexMap[id]!
            ForEach(0..<6, id: \.self) { i in
                ForEach(0..<6, id: \.self) { j in
                    gestureCellView(id: id, i: i, j: j, z: z, gridSize: gridSize)
                }
            }
        }
    }
    
    
    
    // Generate element layer
    @ViewBuilder
    private func elementModelLayer(gridSize: (cellWidth: CGFloat, cellHeight: CGFloat)) -> some View {
    ForEach(elementModel.elements, id: \.id) { elem in
        // let _ = print("📐 Element ID: \(elem.id), grid: \(elem.grid)")
        elementView(for: elem, gridSize: gridSize)
    }
    }

    
    struct CustomFontModifier: ViewModifier {
        func body(content: Content) -> some View {
            content.font(SwiftUI.Font.system(size: 12, weight: .regular, design: .default))
        }
    }
    struct CustomText: View {
        let content: String
        var body: some View {
            Text(content)
                .font(SwiftUI.Font.system(size: 12, weight: .regular, design: .default))
                .foregroundColor(.yellow)
        }
    }
    @ViewBuilder
    private func elementView(for elem: Element, gridSize: (cellWidth: CGFloat, cellHeight: CGFloat)) -> some View {
        let cellSize = elem.computedSizeIgnoringSafeArea(with: gridSize)
        let offset = elem.computedOffsetIgnoringSafeArea(with: CGSize(width: gridSize.cellWidth, height: gridSize.cellHeight))

        if cellSize.width.isFinite && cellSize.height.isFinite {
            if elem.id == "Repeat" {
                // Refactor the complex view chain for Repeat
                let baseRectangle = RoundedRectangle(cornerRadius: 4)
                let stroked = baseRectangle.strokeBorder(.white, lineWidth: 1)
                let backgrounded = stroked.background(musicManager.isRepeatEnabled ? Color.green : Color.gray)
                let opacityApplied = backgrounded.opacity(musicManager.isRepeatEnabled ? 0.6 : 0.3)
                let overlayed = opacityApplied.overlay(
                    Text("Repeat")
                        .font(SwiftUI.Font.system(size: 12, weight: .regular, design: .default))
                        .foregroundColor(.yellow)
                )
                let framed = overlayed.frame(width: cellSize.width, height: cellSize.height)
                let shaped = framed.contentShape(Rectangle())
                let tapHandled = shaped.onTapGesture {
                    print("🖱️ onTapGesture 発火 → ID: Repeat")
                    ({ () -> Void in
                        let handler: (String, CGSize?, CGPoint?) -> Void = soundVM.handleInteraction
                        handler("Repeat", nil, nil)
                    })()
                }
                let hitTested = tapHandled.allowsHitTesting(true)
                let zIndexed = hitTested.zIndex(100)
                let composed = zIndexed
                composed.offset(offset)
            } else if elem.id == "Shuffle" {
                // Refactor the complex view chain for Shuffle
                let base = RoundedRectangle(cornerRadius: 4)
                let stroked = base.strokeBorder(.white, lineWidth: 1)
                let bgApplied = stroked.background(musicManager.isShuffleEnabled ? Color.green : Color.gray)
                let opacityApplied = bgApplied.opacity(musicManager.isShuffleEnabled ? 0.6 : 0.3)
                let overlayed = opacityApplied.overlay(
                    Text("Shuffle")
                        .font(SwiftUI.Font.system(size: 12, weight: .regular, design: .default))
                        .foregroundColor(.yellow)
                )
                let framed = overlayed.frame(width: cellSize.width, height: cellSize.height)
                let shaped = framed.contentShape(Rectangle())
                let tapHandled = shaped.onTapGesture {
                    print("🖱️ onTapGesture 発火 → ID: Shuffle")
                    ({ () -> Void in
                        let handler: (String, CGSize?, CGPoint?) -> Void = soundVM.handleInteraction
                        handler("Shuffle", nil, nil)
                    })()
                }
                let hitTested = tapHandled.allowsHitTesting(true)
                let zIndexed = hitTested.zIndex(100)
                let composed = zIndexed
                composed.offset(offset)
            } else if elem.id.hasPrefix("PhS") {
             let isOnBinding = Binding<Bool>(
                 get: { soundVM.phaseSwitches[elem.id] ?? false },
                 set: { newValue in soundVM.phaseSwitches[elem.id] = newValue }
             )
             RoundedRectangle(cornerRadius: 4)
                 .strokeBorder(.white, lineWidth: 1)
                 .background(
                     isOnBinding.wrappedValue ? Color.green : Color.gray
                 )
                 .opacity(isOnBinding.wrappedValue ? 0.6 : 0.3)
                 .overlay(
                     Text(elem.id)
                         .modifier(CustomFontModifier())
                         .foregroundColor(.yellow)
                 )
                 .frame(width: cellSize.width, height: cellSize.height)
                 .contentShape(Rectangle())
                 .onTapGesture {
                     print("🖱️ onTapGesture 発火 → ID: \(elem.id)")
                     ({ () -> Void in
                         let handler: (String, CGSize?, CGPoint?) -> Void = soundVM.handleInteraction
                         handler(elem.id, nil, nil)
                     })()
                 }
       
                 .allowsHitTesting(true)
                 .zIndex(100)
                 .offset(offset)
         } else if elem.id.hasPrefix("PS") {
             let isOnBinding = Binding<Bool>(
                 get: { soundVM.pickupSwitches[elem.id] ?? false },
                 set: { newValue in soundVM.pickupSwitches[elem.id] = newValue }
             )
             RoundedRectangle(cornerRadius: 4)
                 .strokeBorder(.white, lineWidth: 1)
                 .background(
                     isOnBinding.wrappedValue ? Color.red : Color.gray
                 )
                 .opacity(isOnBinding.wrappedValue ? 0.6 : 0.3)
                 .overlay(
                     Text(elem.id)
                         .modifier(CustomFontModifier())
                         .foregroundColor(.yellow)
                 )
                 .frame(width: cellSize.width, height: cellSize.height)
                 .contentShape(Rectangle())
                 .onTapGesture {
                     print("🖱️ onTapGesture 発火 → ID: \(elem.id)")
                     ({ () -> Void in
                          let handler: (String, CGSize?, CGPoint?) -> Void = soundVM.handleInteraction
                          handler(elem.id, nil, nil)
                     })()
                 }
                 .allowsHitTesting(true)
                 .zIndex(100)
                 .offset(offset)
         } else if elem.id == "FretScope" {
         FretScopeView(
             redVM: soundVM,
             selectedFretIndex: $selectedFretIndex,
             selectedScatSymbol: $selectedScatSymbol
         )
         .onChange(of: selectedFretIndex) {
             soundVM.fretDouble = Double(selectedFretIndex)
         }
         .onChange(of: selectedScatSymbol) { _, newScat in
             if let scat = newScat, !scat.isEmpty {
                 for id in selectedCellIDs {
                     if let cell = model.cubeCells.first(where: { $0.id == id }) {
                         cell.scatSymbol = scat
                         cell.objectWillChange.send()
                     }
                 }
                 selectedScatSymbol = nil
                 selectedCellIDs.removeAll()
             }
         }
         .frame(width: cellSize.width, height: cellSize.height)
         .background(Color.black.opacity(0.1))
         .offset(offset)
         .zIndex(100)
         } else if elem.id == "TA" {
             ZStack(alignment: .center) {
                 RoundedRectangle(cornerRadius: 4)
                     .strokeBorder(Color.gray, lineWidth: 0.5)
                     .background(Color.gray.opacity(0.1))
                     .contentShape(Rectangle())
                     .zIndex(1)

                 VStack {
                     TAHorizontalSlider(
                         value: Binding<Double>(
                             get: { soundVM.taValue },
                             set: { soundVM.taValue = $0.rounded() }
                         ),
                         range: 0...10,
                         step: 1
                     )
                     .frame(width: cellSize.width * 0.8, height: cellSize.height * 0.8)
                 }
                 .padding(4)
                 .zIndex(2)
             }
             .frame(width: cellSize.width, height: cellSize.height)
             .offset(offset)
             .allowsHitTesting(true)
             .zIndex(100)
         } else if elem.id == "T" {
             let toneBinding = Binding<Double>(
                 get: { soundVM.toneValueT },
                 set: { newVal in soundVM.toneValueT = newVal.rounded() }
             )
 
             ZStack {
                 RoundedRectangle(cornerRadius: 4)
                     .strokeBorder(.gray, lineWidth: 1)
                     .background(Color.gray.opacity(0.3))
                 VStack(spacing: 2) {
                     Text("T (\(String(format: "%.1f", soundVM.toneValueT)))")
                         .font(SwiftUI.Font.caption2)
                         .foregroundColor(.yellow)
                     Slider(value: toneBinding, in: 0...15, step: 1)
                         .frame(height: cellSize.height * 0.3)
                         .tint(.yellow)
                 }
                 .padding(4)
             }
             .frame(width: cellSize.width, height: cellSize.height)
             .offset(offset)
             .zIndex(100)
         } else if elem.id == "V" {
             let velocityBinding = Binding<Double>(
                 get: { Double(soundVM.velocity) },
                 set: { newVal in soundVM.velocity = Int(newVal.rounded()) }
             )
 
             ZStack {
                 RoundedRectangle(cornerRadius: 4)
                     .strokeBorder(.gray, lineWidth: 1)
                     .background(Color.gray.opacity(0.3))
                 VStack(spacing: 2) {
                     Text("V (\(soundVM.velocity))")
                         .font(SwiftUI.Font.caption2)
                         .foregroundColor(.yellow)
                     Slider(value: velocityBinding, in: 0...127, step: 1)
                         .frame(height: cellSize.height * 0.3)
                         .tint(.yellow)
                 }
                 .padding(4)
             }
             .frame(width: cellSize.width, height: cellSize.height)
             .offset(offset)
             .zIndex(100)
         } else if elem.id == "VolumeSlider" {
             let volumeBinding = Binding<Double>(
                 get: { soundVM.volumeValue },
                 set: { newVal in
                     soundVM.updateVolume(newVal.rounded())
                 }
             )
 
             ZStack {
                 RoundedRectangle(cornerRadius: 4)
                     .strokeBorder(.white, lineWidth: 1)
                     .background(Color.gray.opacity(0.3))
                 VStack(spacing: 2) {
                     Text("Vol (\(String(format: "%.1f", soundVM.volumeValue)))")
                         .font(SwiftUI.Font.caption2)
                         .foregroundColor(.yellow)
                     Slider(value: volumeBinding, in: 0...127, step: 1)
                         .frame(height: cellSize.height * 0.3)
                         .tint(.yellow)
                 }
                 .padding(4)
             }
             .frame(width: cellSize.width, height: cellSize.height)
             .offset(offset)
             .zIndex(100)
         } else if elem.id == "Select" {
             let isSelected = musicManager.isFileSelected
             let baseRectangle = RoundedRectangle(cornerRadius: 4)
             let stroked = baseRectangle.strokeBorder(.white, lineWidth: 1)
             let backgrounded = stroked.background(isSelected ? Color.green : Color.gray)
             let overlayed = backgrounded.overlay(
                 VStack {
                     Text(isSelected ? "Selected" : "Select")
                         .foregroundColor(.yellow)
                     if let folderName = MusicManager.shared.currentFolderName {
                         Text(folderName)
                             .font(.system(size: 10))
                             .foregroundColor(.green)
                     }
                 }
             )
             overlayed
                 .frame(width: cellSize.width, height: cellSize.height)
                 .contentShape(Rectangle())
                 .onTapGesture {
                     print("🖱️ onTapGesture 発火 → ID: Select")
                     MusicManager.shared.promptMusicSourceSelection()
                 }
                 .zIndex(100)
                 .offset(offset)
         } else if elem.id == "HotSpace" {
             // Show dynamic text based on whether there is undo history
             let hasHistory = !mappingModel.cubicModel.moveHistory.isEmpty
             let base = RoundedRectangle(cornerRadius: 4)
             let stroked = base.strokeBorder(Color.white, lineWidth: 1)
             let backgrounded = stroked.background(Color.gray.opacity(0.3))
             let overlayed = backgrounded.overlay(
                 Group {
                     if hasHistory {
                         (
                             Text("Keep Passing The Open Window\n")
                                 .font(.system(size: 12, weight: .bold, design: .serif))
                                 .foregroundColor(.pink)
                             +
                             Text("Press Here!!")
                                 .font(.system(size: 17, weight: .heavy, design: .rounded))
                                 .foregroundColor(.pink)
                         )
                         .multilineTextAlignment(.center)
                         .shadow(color: .pink, radius: 10)
                         .frame(maxWidth: .infinity, maxHeight: .infinity)
                         .padding(4)
                     } else {
                         Text("HotSpace")
                             .font(.system(size: 12, weight: .regular, design: .default))
                             .foregroundColor(.yellow)
                             .multilineTextAlignment(.center)
                             .frame(maxWidth: .infinity, maxHeight: .infinity)
                             .padding(4)
                     }
                 }
             )
             let framed = overlayed.frame(width: cellSize.width, height: cellSize.height)
             let shaped = framed.contentShape(Rectangle())
             let tapHandled = shaped.onTapGesture {
                 // Trigger undo via HotSpace interaction
                 soundVM.handleInteraction(for: "HotSpace", translation: nil, swipeVelocity: nil)
             }
             let hitTested = tapHandled.allowsHitTesting(true)
             let zIndexed = hitTested.zIndex(100)
             zIndexed.offset(offset)
         } else if elem.id == "Next" {
             let baseRectangle = RoundedRectangle(cornerRadius: 4)
             let stroked = baseRectangle.strokeBorder(.white, lineWidth: 1)
             let backgrounded = stroked.background(Color.gray)
             let overlayed = backgrounded.overlay(
                 Text("Next")
                     .font(SwiftUI.Font.system(size: 12, weight: .regular, design: .default))
                     .foregroundColor(nextButtonFlashRed ? .red : .yellow)
             )
             let framed = overlayed.frame(width: cellSize.width, height: cellSize.height)
             let shaped = framed.contentShape(Rectangle())
             let tapHandled = shaped.onTapGesture {
                 print("🖱️ onTapGesture 発火 → ID: Next")
                 ({ () -> Void in
                     let handler: (String, CGSize?, CGPoint?) -> Void = soundVM.handleInteraction
                     handler("Next", nil, nil)
                 })()
             }
             let hitTested = tapHandled.allowsHitTesting(true)
             let zIndexed = hitTested.zIndex(100)
             zIndexed.offset(offset)
         } else if elem.id == "Prev" {
             let baseRectangle = RoundedRectangle(cornerRadius: 4)
             let stroked = baseRectangle.strokeBorder(.white, lineWidth: 1)
             let backgrounded = stroked.background(Color.gray)
             let overlayed = backgrounded.overlay(
                 Text("Prev")
                     .font(SwiftUI.Font.system(size: 12, weight: .regular, design: .default))
                     .foregroundColor(prevButtonFlashRed ? .red : .yellow)
             )
             let framed = overlayed.frame(width: cellSize.width, height: cellSize.height)
             let shaped = framed.contentShape(Rectangle())
             let tapHandled = shaped.onTapGesture {
                 print("🖱️ onTapGesture 発火 → ID: Prev")
                 ({ () -> Void in
                     let handler: (String, CGSize?, CGPoint?) -> Void = soundVM.handleInteraction
                     handler("Prev", nil, nil)
                 })()
             }
             let hitTested = tapHandled.allowsHitTesting(true)
             let zIndexed = hitTested.zIndex(100)
             zIndexed.offset(offset)
         } else {
             let _ = min(22, soundVM.fret + max(1, soundVM.fretWidth) - 1)
             let isFret = elem.id.starts(with: "F")
             let fretIndex = isFret ? Int(elem.id.dropFirst()) : nil
             let isSelectedFret = (fretIndex != nil) ? (fretIndex! == selectedFretIndex) : false
             let isPhaseSwitchOn = elem.id.hasPrefix("PhS") && (soundVM.phaseSwitches[elem.id] ?? false)
             let isPickupSwitchOn = elem.id.hasPrefix("PS") && (soundVM.pickupSwitches[elem.id] ?? false)
             
             let fillColor: Color = {
                 if isSelectedFret { return Color.orange.opacity(0.8) }
                 else if isPhaseSwitchOn { return Color.green.opacity(0.6) }
                 else if isPickupSwitchOn { return Color.red.opacity(0.6) }
                 else { return Color.gray.opacity(0.3) }
             }()
             let strokeColor: Color = isSelectedFret ? Color.orange : Color.white
 
             RoundedRectangle(cornerRadius: 4)
                 .strokeBorder(strokeColor, lineWidth: 1)
                 .background(fillColor)
                 .overlay(CustomText(content: elem.id))
                 .frame(width: cellSize.width, height: cellSize.height)
                 .contentShape(Rectangle())
                 .onTapGesture {
                     print("🖱️ onTapGesture 発火 → ID: \(elem.id)")
                     if isFret, let fretIndex = fretIndex {
                         selectedFretIndex = fretIndex
                         print("🎸 Fret selected → \(selectedFretIndex)")
                     } else {
                         let interactionHandler: (String, CGSize?, CGPoint?) -> Void = soundVM.handleInteraction
                         interactionHandler(elem.id, nil, nil)
                     }
                 }
                 .allowsHitTesting(true)
                 .zIndex(100)
                 .offset(offset)
         }
        } else {
            EmptyView()
        }
    }


    func showActionSheet() {
        // Disabled onAppear alert for now
    }

    /// Placeholder for the Play and Undo action logic.
    func playAndUndo() {
        // TODO: Implement play and undo logic here
        print("▶️ Undo (playAndUndo) button pressed")
    }
}

struct MainContainerView_Previews: PreviewProvider {
    static var previews: some View {
        MainContainerView()
    }
}

extension Element {
    func computedSizeIgnoringSafeArea(with gridSize: (cellWidth: CGFloat, cellHeight: CGFloat)) -> CGSize {
        return CGSize(width: CGFloat(grid[2]) * gridSize.cellWidth, height: CGFloat(grid[3]) * gridSize.cellHeight)
    }

    func computedOffsetIgnoringSafeArea(with cellSize: CGSize) -> CGSize {
        return CGSize(width: CGFloat(grid[0]) * cellSize.width, height: CGFloat(grid[1]) * cellSize.height)
    }
}




// MARK: - Element and its layout extensions
public struct Element: Identifiable {
    public let id: String
    public let grid: [Int]             // [x, y, w, h]
    public let color: String?
    public var label: String? = nil
    public let orbitElements: String?
    public let subElements: String?
}

// MARK: - ElementModel

public final class ElementModel: ObservableObject {
    // UI側で参照される elements プロパティ
    @Published public var elements: [Element] = [
        
        Element(id: "FretScope", grid: [0, 0, 10, 22], color: nil, orbitElements: nil, subElements: nil),
        
        Element(id: "F1", grid: [10, 0, 2, 1], color: nil, orbitElements: nil, subElements: nil),
        Element(id: "F2", grid: [10, 1, 2, 1], color: nil, orbitElements: nil, subElements: nil),
        Element(id: "F3", grid: [10, 2, 2, 1], color: nil, orbitElements: nil, subElements: nil),
        Element(id: "F4", grid: [10, 3, 2, 1], color: nil, orbitElements: nil, subElements: nil),
        Element(id: "F5", grid: [10, 4, 2, 1], color: nil, orbitElements: nil, subElements: nil),
        Element(id: "F6", grid: [10, 5, 2, 1], color: nil, orbitElements: nil, subElements: nil),
        Element(id: "F7", grid: [10, 6, 2, 1], color: nil, orbitElements: nil, subElements: nil),
        Element(id: "F8", grid: [10, 7, 2, 1], color: nil, orbitElements: nil, subElements: nil),
        Element(id: "F9", grid: [10, 8, 2, 1], color: nil, orbitElements: nil, subElements: nil),
        Element(id: "F10", grid: [10, 9, 2, 1], color: nil, orbitElements: nil, subElements: nil),
        Element(id: "F11", grid: [10, 10, 2, 1], color: nil, orbitElements: nil, subElements: nil),
        Element(id: "F12", grid: [10, 11, 2, 1], color: nil, orbitElements: nil, subElements: nil),
        Element(id: "F13", grid: [10, 12, 2, 1], color: nil, orbitElements: nil, subElements: nil),
        Element(id: "F14", grid: [10, 13, 2, 1], color: nil, orbitElements: nil, subElements: nil),
        Element(id: "F15", grid: [10, 14, 2, 1], color: nil, orbitElements: nil, subElements: nil),
        Element(id: "F16", grid: [10, 15, 2, 1], color: nil, orbitElements: nil, subElements: nil),
        Element(id: "F17", grid: [10, 16, 2, 1], color: nil, orbitElements: nil, subElements: nil),
        Element(id: "F18", grid: [10, 17, 2, 1], color: nil, orbitElements: nil, subElements: nil),
        Element(id: "F19", grid: [10, 18, 2, 1], color: nil, orbitElements: nil, subElements: nil),
        Element(id: "F20", grid: [10, 19, 2, 1], color: nil, orbitElements: nil, subElements: nil),
        Element(id: "F21", grid: [10, 20, 2, 1], color: nil, orbitElements: nil, subElements: nil),
        Element(id: "F22", grid: [10, 21, 2, 1], color: nil, orbitElements: nil, subElements: nil),
        

        Element(id: "TA", grid: [12, 28, 6, 18], color: nil, orbitElements: nil, subElements: nil),

        Element(id: "HotSpace", grid: [12, 0, 6, 6], color: nil, orbitElements: nil, subElements: nil),
        Element(id: "Select", grid: [12, 6, 6, 3], color: nil, orbitElements: nil, subElements: nil),
        Element(id: "PlayPause", grid: [12, 9, 6, 6], color: nil, orbitElements: nil, subElements: nil),
        Element(id: "VolumeSlider", grid: [12, 15, 6, 4], color: nil, orbitElements: nil, subElements: nil),
        
        Element(id: "Prev", grid: [12, 19, 3, 2], color: nil, orbitElements: nil, subElements: nil),
        Element(id: "Next", grid: [15, 19, 3, 2], color: nil, orbitElements: nil, subElements: nil),
        Element(id: "Repeat", grid: [12, 21, 3, 1], color: nil, orbitElements: nil, subElements: nil),
        Element(id: "Shuffle", grid: [15, 21, 3, 1], color: nil, orbitElements: nil, subElements: nil),
        Element(id: "T", grid: [1, 41, 4, 2], color: nil, orbitElements: nil, subElements: nil),
        Element(id: "V", grid: [1, 44, 4, 2], color: nil, orbitElements: nil, subElements: nil),
        Element(id: "PS1", grid: [1, 30, 2, 2], color: nil, orbitElements: nil, subElements: nil),
        Element(id: "PS2", grid: [1, 34, 2, 2], color: nil, orbitElements: nil, subElements: nil),
        Element(id: "PS3", grid: [1, 38, 2, 2], color: nil, orbitElements: nil, subElements: nil),
        Element(id: "PhS1", grid: [3, 29, 2, 2], color: nil, orbitElements: nil, subElements: nil),
        Element(id: "PhS2", grid: [3, 33, 2, 2], color: nil, orbitElements: nil, subElements: nil),
        Element(id: "PhS3", grid: [3, 37, 2, 2], color: nil, orbitElements: nil, subElements: nil),

    ]
}






struct UnifiedCubeCellView: View {
    @ObservedObject var cell: CubeCell
    let element: Element?
    let gridSize: (cellWidth: CGFloat, cellHeight: CGFloat)
    let soundVM: SwitchViewModel
    @Binding var selectedCellIDs: Set<String>
    @Binding var selectedScatSymbol: String?

    // Helper function for selection overlay
    @ViewBuilder
    func selectionOverlay() -> some View {
        if selectedCellIDs.contains(cell.id),
           [.left, .front, .right].contains(cell.facelet.face) {
            ZStack {
                RoundedRectangle(cornerRadius: 0)
                    .fill(Color.yellow.opacity(1.0))  // ✅ ピンク色の背景で選択を強調
                RoundedRectangle(cornerRadius: 0)
                    .stroke(Color.yellow, lineWidth: 4)
            }
        } else {
            EmptyView()
        }
    }

    var body: some View {
        let grid = cell.facelet.grid
        let xOffset = CGFloat(grid.x) * gridSize.cellWidth
        let yOffset = CGFloat(grid.y) * gridSize.cellHeight
        ZStack {
            // Base cell (no SCAT overlay here)
            Rectangle()
                .fill(cell.color)
                .overlay(Rectangle().stroke(Color.black, lineWidth: 1))
                .zIndex(10)
                .contentShape(Rectangle())
                .allowsHitTesting(true)
                .onTapGesture {
                    print("🐞 Tapped cell.id = \(cell.id), selectedScatSymbol = \(selectedScatSymbol ?? "-")")
                    guard [.left, .front, .right].contains(cell.facelet.face) else { return }
                    if selectedCellIDs.contains(cell.id) {
                        selectedCellIDs.remove(cell.id)
                        // Remove SCAT symbol if already present
                        if cell.scatSymbol != nil {
                            cell.scatSymbol = nil
                            cell.objectWillChange.send()
                        }
                    } else {
                        selectedCellIDs.insert(cell.id)
                    }
                }

            // SCAT symbol overlay: show only stored SCAT symbol
            if let stored = cell.scatSymbol, !stored.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(stored)
                    .font(.system(size: min(gridSize.cellHeight * 0.6, 14), weight: .bold))
                    .italic()
                    .foregroundColor(.black)
                    .frame(width: gridSize.cellWidth, height: gridSize.cellHeight)
                    .multilineTextAlignment(.center)
                    .allowsHitTesting(false)
                    .zIndex(999)
            }

            // Selection border
            selectionOverlay()

            // Element overlay
            if let element = element {
                RoundedRectangle(cornerRadius: 4)
                    .strokeBorder(Color.black, lineWidth: 1)
                    .background(Color.gray.opacity(0.3))
                    .overlay(
                        Text(element.id)
                            .font(.system(size: 12, weight: .regular))
                            .foregroundColor(.yellow)
                    )
                    .zIndex(2)
            }
        }
        .frame(
            width: gridSize.cellWidth,
            height: gridSize.cellHeight
        )
        .offset(x: xOffset, y: yOffset)
    }
}


public var cubeCellColorMap: [String: Color] = [:]



public enum Axis {
    case x, y, z
}


public final class CubeCell: ObservableObject, Identifiable, Hashable {
    public let id: String
    public let number: Int
    public let color: Color
    public let colorName: String
    @Published public var facelet: Facelet
    @Published public var scatSymbol: String? = nil

    public init(id: String, number: Int, color: Color, colorName: String, facelet: Facelet) {
        self.id = id
        self.number = number
        self.color = color
        self.colorName = colorName
        self.facelet = facelet
    }

    public var faceName: String {
        switch number {
        case 0..<36: return "L"
        case 36..<72: return "F"
        case 72..<108: return "R"
        case 108..<144: return "D"
        case 144..<180: return "B"
        case 180..<216: return "U"
        default: return "?"
        }
    }
    
    public static func == (lhs: CubeCell, rhs: CubeCell) -> Bool {
        return lhs.id == rhs.id
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

}

public struct Rotation {
    public let axis: Axis3D
    public let index: Int
    public let clockwise: Bool

    public func apply(to pos: Pos3D) -> Pos3D {
    let N = 6
    switch axis {
    case .x:
        if clockwise {
            return Pos3D(x: pos.x, y: pos.z, z: N - 1 - pos.y)
        } else {
            return Pos3D(x: pos.x, y: N - 1 - pos.z, z: pos.y)
        }
    case .y:
        if clockwise {
            return Pos3D(x: N - 1 - pos.z, y: pos.y, z: pos.x)
        } else {
            return Pos3D(x: pos.z, y: pos.y, z: N - 1 - pos.x)
        }
    case .z:
        if clockwise {
            return Pos3D(x: pos.y, y: N - 1 - pos.x, z: pos.z)
        } else {
            return Pos3D(x: N - 1 - pos.y, y: pos.x, z: pos.z)
        }
    }
    }

    public func matchesLayer(_ pos: Pos3D) -> Bool {
        switch axis {
        case .x: return pos.x == index
        case .y: return pos.y == index
        case .z: return pos.z == index
        }
    }
}


public func generateCubeCells() -> [CubeCell] {
    var result: [CubeCell] = []
    
    for i in 0..<216 {
        let x = i % 6
        let y = (i / 6) % 6
        let id = String(format: "C%02d", i)
        let number = i

        let fx = x
        let fy = y

        let face: CubeFace
        switch number {
        case 0..<36: face = .left
        case 36..<72: face = .front
        case 72..<108: face = .right
        case 108..<144: face = .bottom
        case 144..<180: face = .back
        case 180..<216: face = .top
        default: face = .front
        }

        let faceOrigin = getFaceOrigin(for: face)
        let gridPosition = GridPosition(x: fx + faceOrigin.originX, y: fy + faceOrigin.originY)
        let pos3D: Pos3D
        switch face {
        case .left: pos3D = Pos3D(x: 0, y: y, z: 5 - x)
        case .right: pos3D = Pos3D(x: 5, y: y, z: x)
        case .top: pos3D = Pos3D(x: x, y: 0, z: y)
        case .bottom: pos3D = Pos3D(x: x, y: 5, z: y)
        case .front: pos3D = Pos3D(x: x, y: y, z: 1)
        case .back: pos3D = Pos3D(x: x, y: y, z: 4)
        }
        let facelet = Facelet(face: face, i: fx, j: fy, grid: gridPosition, pos3D: pos3D)

        let color: Color
        let colorName: String
        switch face {
        case .left: color = .red; colorName = "red"
        case .front: color = .blue; colorName = "blue"
        case .right: color = .green; colorName = "green"
        case .bottom: color = .orange; colorName = "orange"
        case .back: color = .yellow; colorName = "yellow"
        case .top: color = .white; colorName = "white"
        }

        result.append(CubeCell(id: id, number: number, color: color, colorName: colorName, facelet: facelet))
        //print("🧩 Generated cell: id=\(id), pos3D=\(pos3D), colorName=\(colorName)")
    }

    return result
}


// MappingEntry only retains grid values
public func generateMappingEntries(cubeCells: [CubeCell]) -> [MappingEntry] {
    var entries: [MappingEntry] = []

    for layout in GridConfig.faceLayouts {
        guard let cubeFace = CubeFace(rawValue: layout.name) else { continue }
        let originX = layout.originX, originY = layout.originY

        for i in 0..<6 {
            for j in 0..<6 {
                
                let gridX = originX + i
                let gridY = originY + j
                let grid = [gridX, gridY, 1, 1]
                
                let id = MappingEntryID(faceName: cubeFace.rawValue, i: i, j: j, grid: grid)
                let entry = MappingEntry(id: id, grid: grid)
                entries.append(entry)
            }
        }
    }

    return entries
}

struct GridConfig {
    static let cellSize = 6
    static let totalColumns = 24
    static let totalRows = 20

    static let faceLayouts: [(name: String, axis: Axis, fixed: Int, originX: Int, originY: Int)] = [
        ("left", .z, 0, 0, 22),
        ("front", .z, 1, 6, 22),
        ("right", .z, 2, 12, 22),
        ("bottom", .z, 3, 6, 28),
        ("back", .z, 4, 6, 34),
        ("top", .z, 5, 6, 40)
    ]
}

public class CubicModel: ObservableObject {
    public static let staticGrids: [MappingEntry] = []
    
    @Published var cubeCells: [CubeCell]
    public var grids: [MappingEntry]
    var moveHistory: [Move] = []
    
    
    

    
    public init() {
        let cells = generateCubeCells()
        self.cubeCells = cells
        self.grids = generateMappingEntries(cubeCells: cells)
    }
    
    // (rotateFace, applyRotation, rotatedPosition removed as unused)
    func rotateSlice(for pos3D: Pos3D, axis: Axis3D, sliceIndex: Int, clockwise: Bool = true) {
        //let N = 6
        
        print("🔁 Executing rotateSlice: axis=\(axis), index=\(sliceIndex), clockwise=\(clockwise)")
        let sliceCells = cubeCells.filter { cell in
            let p = cell.facelet.pos3D
            switch axis {
            case .x: return p.x == sliceIndex
            case .y: return p.y == sliceIndex
            case .z: return p.z == sliceIndex
            }
        }
        // for cell in sliceCells {
        //     print("🔄 \(cell.id) → \(cell.facelet.face)(\(cell.facelet.i),\(cell.facelet.j)) @ \(cell.facelet.grid.x),\(cell.facelet.grid.y)")
        // }
        
        // Moved rotation logic blocks into rotateSlice
        if axis == .y {
            let lefts = sliceCells.filter { $0.facelet.face == .left }.sorted { $0.facelet.i < $1.facelet.i }
            let fronts = sliceCells.filter { $0.facelet.face == .front }.sorted { $0.facelet.i < $1.facelet.i }
            let rights = sliceCells.filter { $0.facelet.face == .right }.sorted { $0.facelet.i < $1.facelet.i }
            let backs = sliceCells.filter { $0.facelet.face == .back }.sorted { $0.facelet.i < $1.facelet.i }
            
            if lefts.count == 6 && fronts.count == 6 && rights.count == 6 && backs.count == 6 {
                let temp = lefts.map { $0.facelet }
                
                for i in 0..<6 {
                    if clockwise {
                        lefts[i].facelet = backs[i].facelet
                        backs[i].facelet = rights[i].facelet
                        rights[i].facelet = fronts[i].facelet
                        fronts[i].facelet = temp[i]
                    } else {
                        lefts[i].facelet = fronts[i].facelet
                        fronts[i].facelet = rights[i].facelet
                        rights[i].facelet = backs[i].facelet
                        backs[i].facelet = temp[i]
                    }
                }
                
                print("✅ Y-axis facelet-based rotation applied (6-unit shift)")
                self.objectWillChange.send()
                return
            } else {
                print("⚠️ Not all faces present for Y-axis rotation")
            }
        }
        
        if axis == .z {
            let tops = sliceCells.filter { $0.facelet.face == .top }.sorted { $0.facelet.i < $1.facelet.i }
            let rights = sliceCells.filter { $0.facelet.face == .right }.sorted { $0.facelet.j < $1.facelet.j }
            let bottoms = sliceCells.filter { $0.facelet.face == .bottom }.sorted { $0.facelet.i > $1.facelet.i }
            let lefts = sliceCells.filter { $0.facelet.face == .left }.sorted { $0.facelet.j > $1.facelet.j }
            
            if tops.count == 6 && rights.count == 6 && bottoms.count == 6 && lefts.count == 6 {
                let temp = tops.map { $0.facelet }
                
                for i in 0..<6 {
                    if clockwise {
                        tops[i].facelet = lefts[i].facelet
                        lefts[i].facelet = bottoms[i].facelet
                        bottoms[i].facelet = rights[i].facelet
                        rights[i].facelet = temp[i]
                    } else {
                        tops[i].facelet = rights[i].facelet
                        rights[i].facelet = bottoms[i].facelet
                        bottoms[i].facelet = lefts[i].facelet
                        lefts[i].facelet = temp[i]
                    }
                }
                
                print("✅ Z-axis facelet-based rotation applied (6-unit shift)")
                self.objectWillChange.send()
                return
            } else {
                print("⚠️ Not all faces present for Z-axis rotation")
            }
        }
        
        if axis == .x {
            let tops = sliceCells.filter { $0.facelet.face == .top }.sorted { $0.facelet.j < $1.facelet.j }
            let fronts = sliceCells.filter { $0.facelet.face == .front }.sorted { $0.facelet.j < $1.facelet.j }
            let bottoms = sliceCells.filter { $0.facelet.face == .bottom }.sorted { $0.facelet.j > $1.facelet.j }
            let backs = sliceCells.filter { $0.facelet.face == .back }.sorted { $0.facelet.j > $1.facelet.j }
            
            if tops.count == 6 && fronts.count == 6 && bottoms.count == 6 && backs.count == 6 {
                let temp = tops.map { $0.facelet }
                
                for i in 0..<6 {
                    if clockwise {
                        tops[i].facelet = backs[i].facelet
                        backs[i].facelet = bottoms[i].facelet
                        bottoms[i].facelet = fronts[i].facelet
                        fronts[i].facelet = temp[i]
                    } else {
                        tops[i].facelet = fronts[i].facelet
                        fronts[i].facelet = bottoms[i].facelet
                        bottoms[i].facelet = backs[i].facelet
                        backs[i].facelet = temp[i]
                    }
                }
                
                print("✅ X-axis facelet-based rotation applied (6-unit shift)")
                self.objectWillChange.send()
                return
            } else {
                print("⚠️ Not all faces present for X-axis rotation")
            }
        }
    }
}


// Extension to implement Rubik's Cube layer rotation based on group theory
extension CubicModel {
    /// Update the position of cells in the specified layer using group-theoretic rotation
    func rotateLayer(at layerIndex: Int, axis: Axis3D, clockwise: Bool) {
        let N = 6
        for i in 0..<cubeCells.count {
            let cell = cubeCells[i]
            switch axis {
            case .x where cell.facelet.pos3D.x == layerIndex,
                 .y where cell.facelet.pos3D.y == layerIndex,
                 .z where cell.facelet.pos3D.z == layerIndex:
                let rotatedPos = rotatePosition(cell.facelet.pos3D, axis: axis, clockwise: clockwise, N: N)
                var newFacelet = cell.facelet
                newFacelet = Facelet(face: newFacelet.face, i: newFacelet.i, j: newFacelet.j, grid: newFacelet.grid, pos3D: rotatedPos)
                cubeCells[i] = CubeCell(id: cell.id, number: cell.number, color: cell.color, colorName: cell.colorName, facelet: newFacelet)
            default:
                break
            }
        }
        objectWillChange.send()
    }
    
    /// Apply a 90° rotation around the specified axis
    private func rotatePosition(_ pos: Pos3D, axis: Axis3D, clockwise: Bool, N: Int) -> Pos3D {
        switch axis {
        case .x:
            return clockwise
                ? Pos3D(x: pos.x, y: N - 1 - pos.z, z: pos.y)
                : Pos3D(x: pos.x, y: pos.z, z: N - 1 - pos.y)
        case .y:
            return clockwise
                ? Pos3D(x: pos.z, y: pos.y, z: N - 1 - pos.x)
                : Pos3D(x: N - 1 - pos.z, y: pos.y, z: pos.x)
        case .z:
            return clockwise
                ? Pos3D(x: pos.y, y: N - 1 - pos.x, z: pos.z)
                : Pos3D(x: N - 1 - pos.y, y: pos.x, z: pos.z)
        }
    }
    
    /// Returns a 6x6x6 array of Color representing the cube's current state.
    func cubeColorArray() -> [[[Color]]] {
        var colors = Array(
            repeating: Array(repeating: Array(repeating: Color.gray, count: 6), count: 6),
            count: 6
        )
        for cell in cubeCells {
            let pos = cell.facelet.pos3D
            colors[pos.z][pos.y][pos.x] = cell.color
        }
        return colors
    }
}




extension Comparable {
    func clamped(to limits: ClosedRange<Self>) -> Self {
        return min(max(self, limits.lowerBound), limits.upperBound)
    }
}




// MARK: - MappingEntryID
public struct MappingEntryID: Hashable, CustomStringConvertible, Equatable {
    public let faceName: String
    public let i: Int
    public let j: Int
    public let grid: [Int]

    public init(faceName: String, i: Int, j: Int, grid: [Int]) {
        self.faceName = faceName
        self.i = i
        self.j = j
        self.grid = grid
    }

    public var description: String {
        return "\(faceName)_\(i)_\(j)_\(grid.map { String($0) }.joined(separator: "_"))"
    }
    
    var gridString: String {
        return grid.map { String($0) }.joined(separator: "-")
    }
}

// MARK: - MappingEntry
public struct MappingEntry: Identifiable {
    public let id: MappingEntryID
    public let grid: [Int]

    public init(id: MappingEntryID, grid: [Int]) {
        self.id = id
        self.grid = grid
    }
}

// MARK: - MappingModel
public class MappingModel: ObservableObject {
    var cubeCellsDictionary: [Pos3D: CubeCell]
    
    @Published public var entries: [MappingEntry] = []
    private var gridToElementID: [MappingEntryID: String] = [:]
    private var elementIDToGrids: [String: [MappingEntryID]] = [:]
    private var mapping: [[[String?]]]
    public var cubicModel: CubicModel

    init(cubicModel: CubicModel) {
        self.cubicModel = cubicModel
        self.cubeCellsDictionary = [:]
        for cell in cubicModel.cubeCells {
            let key = cell.facelet.pos3D
            self.cubeCellsDictionary[key] = cell
        }
        self.mapping = Array(repeating: Array(repeating: Array(repeating: nil, count: 7), count: 7), count: 7)
        updateMappingFromElements()
    }

    func updateMappingFromElements() {
        for z in 0..<7 {
            for y in 0..<7 {
                for x in 0..<7 {
                    mapping[z][y][x] = nil
                }
            }
        }

        //CubeCell
        for cell in cubicModel.cubeCells {
            let pos = cell.facelet.pos3D
            if (0..<7).contains(pos.x) && (0..<7).contains(pos.y) && (0..<7).contains(pos.z) {
                mapping[pos.z][pos.y][pos.x] = cell.id
            }
        }
        objectWillChange.send()
    }
    
    func generateMapping() {
        self.entries = generateMappingEntries(cubeCells: cubicModel.cubeCells)
        self.cubeCellsDictionary = [:]
        for cell in cubicModel.cubeCells {
            let key = cell.facelet.pos3D
            self.cubeCellsDictionary[key] = cell
        }
    }
}

// MARK: - MappingEntryID: Computed property for pos3D
extension MappingEntryID {
    var pos3D: Pos3D {
        let z = GridConfig.faceLayouts.first(where: { $0.name.lowercased() == faceName.lowercased() })?.fixed ?? -1
        return Pos3D(x: i, y: j, z: z)
    }
}

extension Color {
    init?(hex: String) {
        var hexFormatted = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()

        if hexFormatted.hasPrefix("#") {
            hexFormatted.removeFirst()
        }

        guard hexFormatted.count == 6 else {
            return nil
        }

        var rgbValue: UInt64 = 0
        Scanner(string: hexFormatted).scanHexInt64(&rgbValue)

        let red = Double((rgbValue & 0xFF0000) >> 16) / 255.0
        let green = Double((rgbValue & 0x00FF00) >> 8) / 255.0
        let blue = Double(rgbValue & 0x0000FF) / 255.0

        self.init(.sRGB, red: red, green: green, blue: blue, opacity: 1.0)
    }
}

extension Pos3D {
    func toKey() -> String {
        return "\(x)-\(y)-\(z)"
    }
}



extension GridPosition {
    func toArray() -> [Int] {
        return [x, y, 1, 1]
    }
}



    


// CubeCellStore definition as specified
public class CubeCellStore: ObservableObject {
    @Published var cells: [MappingEntryID: CubeCell] = [:]
}

extension GridPosition: Equatable {
    public static func == (lhs: GridPosition, rhs: GridPosition) -> Bool {
        return lhs.x == rhs.x && lhs.y == rhs.y
    }
}



// MARK: - Color Vector Generation (UI Order)
private func cubeCellColorMapKey(for id: MappingEntryID) -> String {
    // Compose a unique key for the color map using face name, i, j.
    return "\(id.faceName)_\(id.i)_\(id.j)"
}

private func createColorVector(mappingModel: MappingModel) -> [String] {
    // This returns the color name (String) for each grid in UI (rendering) order.
    return mappingModel.cubicModel.grids.map { entry in
        let pos3D = entry.id.pos3D
        if let cell = mappingModel.cubeCellsDictionary[pos3D] {
            let colorName = cell.colorName
            print("🎨 ColorName at (\(entry.id.i), \(entry.id.j), \(pos3D.z)) = \(colorName)")
            return colorName
        }
        let colorKey = cubeCellColorMapKey(for: entry.id)
        return cubeCellColorMap[colorKey] != nil ? String(describing: cubeCellColorMap[colorKey]!) : "unknown"
    }
}



// MARK: - CoreML Output FeatureValue Extraction Utility
// If you previously used output.featureValue(for: "latent_output"), use output.featureValue(for: "Identity") instead.
// Example:
// let identityFeature = output.featureValue(for: "Identity")

/// Extracts the latent output MLMultiArray from a CoreML output provider.
/// If you previously used output.featureValue(for: "latent_output"), use this function instead.
func extractLatentOutput(from output: MLFeatureProvider) -> MLMultiArray? {
    return output.featureValue(for: "Identity")?.multiArrayValue
}


// Utility function to convert a Color to a String name
func colorName(from color: Color) -> String {
    switch color {
    case .red: return "red"
    case .blue: return "blue"
    case .green: return "green"
    case .yellow: return "yellow"
    case .orange: return "orange"
    case .white: return "white"
    default: return "unknown"
    }
}




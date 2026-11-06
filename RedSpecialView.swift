
import SwiftUI
import AVFoundation
import CoreML
import MusicKit
import CoreGraphics
import Foundation
import Combine
import QuartzCore



// MARK: - CubeColor enumeration
/// Cube face colors used throughout the audio/visual mapping logic
enum CubeColor {
    case red, yellow, blue, green, orange, white
}

// MARK: - ScrambleStep
/// スクランブル1手分の作曲情報。scrambleHistory の要素。
struct ScrambleStep {
    let colors: [String]                           // 色状態（全セル）
    let scatSymbols: [(grid: [Int], scat: String)] // SCAT配置
    let duration: TimeInterval                     // このステップの音の長さ（スワイプ速度から算出）
    let redSpecialState: RedSpecialState           // その時点のコントロール状態

    /// スワイプ速度 magnitude から duration を算出する
    static func duration(from speed: CGFloat) -> TimeInterval {
        let minDuration: TimeInterval = 0.05
        let maxDuration: TimeInterval = 2.0
        let referenceSpeed: CGFloat = 500.0
        guard speed > 1.0 else { return maxDuration }
        return min(max(referenceSpeed / Double(speed), minDuration), maxDuration)
    }
}

// MARK: - AudioMetadata struct for instrumentID to MLMultiArray
struct AudioMetadata {
    let pitch: Float
    let velocity: Float
    let instrument: Int
    let instrumentFamily: Int
    let instrumentSource: Int
    let qualities: [Float]
    // asMLMultiArray() is now unused and can be removed or commented out
    // func asMLMultiArray() -> MLMultiArray? { ... }
}

// MARK: - SwitchViewModel
class SwitchViewModel: ObservableObject {
    // Added properties for RedSpecialView references
    @Published var ps1: Bool = false
    @Published var ps2: Bool = false
    @Published var ps3: Bool = false
    @Published var phs1: Bool = false
    @Published var phs2: Bool = false
    @Published var phs3: Bool = false
    @Published var ta: Bool = false
    @Published var volume: Double = 1.0
    @Published var tremoloAngle: Double = 0.0
    @Published var directionHint: SIMD2<Double> = .zero
    @Published var dominantPlayer: String = ""
    @Published var scrambleHistory: [ScrambleStep] = []
    func apply(_ state: RedSpecialState) {
        self.ps1 = state.ps1
        self.ps2 = state.ps2
        self.ps3 = state.ps3
        self.phs1 = state.phs1
        self.phs2 = state.phs2
        self.phs3 = state.phs3
        self.ta = state.ta
        self.tone = state.tone
        self.volume = state.volume
        self.tremoloAngle = state.tremoloAngle
        self.directionHint = state.directionHint
        self.dominantPlayer = state.dominantPlayer
    }

    struct OrbitEvent {
        let timestamp: TimeInterval
        let axis: Axis3D
        let index: Int
        let clockwise: Bool
        let affectedCells: [CubeCell]
    }

    struct SoundParameters {
        var colors: [[[Color]]]
        var pickupSwitches: [String: Bool]
        var phaseSwitches: [String: Bool]
        var taValue: Double
        var velocity: Int
        var toneValueT: Double
        var instrumentFamilyStr: String = ""
        var instrumentStr: String = ""
        var qualitiesStrs: [String] = []
    }
    /// Tracks the most recently tapped cell ID for undo/HotSpace playback
    @Published var latestTappedCellID: String?
    @Published var orbitHistory: [OrbitEvent] = []
    @Published var fretWidth: Int = 1
    @Published var fret: Int = 0 {
        didSet {
            if Int(fretDouble.rounded()) != fret {
                fretDouble = Double(fret)
                // print("🔁 fret → fretDouble 更新: \(fret) → \(fretDouble)")
            }
        }
    }
    @Published var fretDouble: Double = 11.5
    /// Selected SCAT symbols for RedScorePlay
    @Published var selectedScatSymbols: [String] = [] {
        didSet {
            let intFret = Int(fretDouble.rounded())
            if fret != intFret {
                fret = intFret
                // print("🔁 fretDouble → fret 更新: \(fretDouble) → \(fret)")
            }
            objectWillChange.send()
        }
    }
    @Published var pickupSwitches: [String: Bool] = [:]
    @Published var phaseSwitches: [String: Bool] = [:]
    @Published var velocity: Int = 100 {
        didSet { /* print("🔄 Velocity 更新: \(velocity)") */ }
    }
    @Published var tone: Double = 5.0 {
        didSet { /* print("🔄 Tone 更新: \(tone)") */ }
    }
    // Single instance of taValue; ensure no duplicate declarations exist.
    @Published var taSwitch: Bool = false
    @Published var taValue: Double = 5.0
    @Published var toneValueT: Double = 5.0
    // MARK: - Play Sound from Color Array with Switch Parameters [REMOVED: see global function playSoundFromColorArray(parameters:)]
    @Published var fretDeltaAccumulated: CGFloat = 0.0
    @Published var volumeValue: Double = 100.0
    /// Keeps strong references to currently playing AVAudioPlayerNodes
    var activePlayers: [AVAudioPlayerNode] = []

    /// Update the volume value, ensuring any UI updates run on the main thread.
    @MainActor
    func updateVolume(_ value: Double) {
        self.volumeValue = value
        // Any additional logic here
        objectWillChange.send()
        // print("🔊 updateVolume called: \(volumeValue)")
    }

    /// Total number of layer rotations (slices) performed
    @Published var sliceCount: Int = 0
    /// History of slice identifiers
    var sliceHistory: [String] = []
    var cubeVM: CubicModel
    var mappingModel: MappingModel
    
    init(cubeVM: CubicModel, mappingModel: MappingModel) {
        self.cubeVM = cubeVM
        self.mappingModel = mappingModel
        // All pickups ON by default to emulate Red Special's flexible tone setup
        self.pickupSwitches = ["PS1": false, "PS2": true, "PS3": true]
        self.phaseSwitches = ["PhS1": false, "PhS2": false, "PhS3": false]
    }

    private enum SoundModelLoadError: LocalizedError {
        case missingCompiledModel(name: String)

        var errorDescription: String? {
            switch self {
            case .missingCompiledModel(let name):
                return "\(name).mlmodelc がアプリバンドルに存在しません"
            }
        }
    }

    private static let availableComputeDevicesSummary: String = {
        let devices = MLModel.availableComputeDevices.map(\.description)
        return devices.isEmpty ? "none" : devices.joined(separator: ", ")
    }()
    private static let soundModelInspectionLock = NSLock()
    private static var inspectedSoundModels = Set<String>()

    private static let prismDecoderLoadResult: Result<MLModel, Error> = {
        do {
            return .success(try loadSoundModel(named: "PrismDecoder"))
        } catch {
            return .failure(error)
        }
    }()

    private static func soundModelConfiguration(displayName: String) -> MLModelConfiguration {
        let config = MLModelConfiguration()
        config.modelDisplayName = displayName
        config.computeUnits = .cpuAndNeuralEngine
        return config
    }

    private static func computeUnitsDescription(_ computeUnits: MLComputeUnits) -> String {
        switch computeUnits {
        case .cpuOnly:
            return "cpuOnly"
        case .cpuAndGPU:
            return "cpuAndGPU"
        case .all:
            return "all"
        case .cpuAndNeuralEngine:
            return "cpuAndNeuralEngine"
        @unknown default:
            return "unknown"
        }
    }

    static func loadSoundModel(named name: String) throws -> MLModel {
        guard let modelURL = Bundle.main.url(forResource: name, withExtension: "mlmodelc") else {
            throw SoundModelLoadError.missingCompiledModel(name: name)
        }

        let config = soundModelConfiguration(displayName: name)
        let model = try MLModel(contentsOf: modelURL, configuration: config)
        print("🧠 \(name) loaded with computeUnits=\(computeUnitsDescription(config.computeUnits)); available devices: \(availableComputeDevicesSummary)")
        inspectSoundModelComputePlan(name: name, modelURL: modelURL)
        return model
    }

    private static func inspectSoundModelComputePlan(name: String, modelURL: URL) {
        soundModelInspectionLock.lock()
        let shouldInspect = inspectedSoundModels.insert(name).inserted
        soundModelInspectionLock.unlock()
        guard shouldInspect else { return }

        Task(priority: .background) {
            do {
                let config = soundModelConfiguration(displayName: name)
                let plan = try await MLComputePlan.load(contentsOf: modelURL, configuration: config)
                let summary = preferredComputeDevicesDescription(for: plan)
                print("🧠 \(name) compute plan preferred devices: \(summary)")
            } catch {
                print("⚠️ \(name) compute plan inspection failed: \(error.localizedDescription)")
            }
        }
    }

    private static func preferredComputeDevicesDescription(for plan: MLComputePlan) -> String {
        var preferredDevices = Set<String>()

        switch plan.modelStructure {
        case .neuralNetwork(let neuralNetwork):
            for layer in neuralNetwork.layers {
                if let usage = plan.deviceUsage(for: layer) {
                    preferredDevices.insert(usage.preferred.description)
                }
            }
        case .program(let program):
            for function in program.functions.values {
                for operation in function.block.operations {
                    if let usage = plan.deviceUsage(for: operation) {
                        preferredDevices.insert(usage.preferred.description)
                    }
                }
            }
        case .pipeline(let pipeline):
            return pipeline.subModelNames.isEmpty
                ? "pipeline"
                : "pipeline[\(pipeline.subModelNames.joined(separator: ", "))]"
        case .unsupported:
            return "unsupported"
        @unknown default:
            return "unknown"
        }

        return preferredDevices.isEmpty
            ? "no device usage reported"
            : preferredDevices.sorted().joined(separator: ", ")
    }

    /// CoreML PrismDecoder model loader
    var prismDecoder: MLModel? {
        switch Self.prismDecoderLoadResult {
        case .success(let model):
            return model
        case .failure(let error):
            print("❌ PrismDecoder load failed: \(error.localizedDescription)")
            return nil
        }
    }
    
// MARK: - Independent Playback Logic
    func playSoundFromColorArray(parameters: SoundParameters) {
        print("🟥 playSoundFromColorArray 呼び出し - 独立関数経由")
        let colors = parameters.colors
        // Determine dominant color and player
        let colorCounts = colors.flatMap { $0 }.flatMap { $0 }.reduce(into: [String: Int]()) { counts, color in
            let name = RedSpecial.colorName(from: color)
            counts[name, default: 0] += 1
        }
        let dominantColor = colorCounts.max { $0.value < $1.value }?.key ?? "unknown"
//        let playerName: String
//        switch dominantColor {
//        case "red": playerName = "Freddie"
//        case "green": playerName = "John"
//        case "blue": playerName = "Brian"
//        case "yellow": playerName = "Roger"
//        default: playerName = "Freddie"
//        }

        let pickupSwitches = parameters.pickupSwitches
        let phaseSwitches = parameters.phaseSwitches
        let taValue = parameters.taValue
        let velocity = parameters.velocity
        let toneValueT = parameters.toneValueT
        let N = 6
        let psOn = pickupSwitches.filter { $0.value }.keys.sorted()
        let phsOn = phaseSwitches.filter { $0.value }.keys.sorted()
        print("🧪 入力パラメータ: PS=\(psOn), PhS=\(phsOn), TA=\(taValue), velocity=\(velocity), toneT=\(toneValueT)")
        // 🔒 PS全OFFなら無音（再生しない）扱い
        if psOn.isEmpty {
            print("🔇 すべてのピックアップがOFF → WAV選択スキップ")
            return
        }

        var baseCode: Int
        switch psOn {
        case ["PS1", "PS2"]:
            baseCode = 045
        case ["PS2", "PS3"]:
            baseCode = 046
        case ["PS1"]:
            baseCode = 047
        case ["PS3"]:
            baseCode = 048
        case ["PS1", "PS3"]:
            baseCode = 050
        case ["PS1", "PS2", "PS3"]:
            baseCode = 052
        default:
            baseCode = 049
        }
        if phsOn.contains("PhS1") || phsOn.contains("PhS2") || phsOn.contains("PhS3") {
            baseCode += 1
        }
        let taAdjust = Int((taValue - 5) / 2.5)  // -2 to +2
        baseCode = (baseCode + taAdjust).clamped(to: 031...067)
        let validVelocities = [25, 50, 75, 100, 127]
        //let nearestVelocity = validVelocities.min(by: { abs($0 - velocity) < abs($1 - velocity) }) ?? 100
        // Log before loop
        print("🔁 同時再生（列単位）処理を開始します")

        // Calculate timing
        let audioManager = AudioEngineManager.shared
        let mainMixer = audioManager.engine.mainMixerNode
        let outputFormat = mainMixer.outputFormat(forBus: 0)
        //let sampleRate = outputFormat.sampleRate
        // EQ and gain configuration
        // (see playBuffersWithPitch for similar processing)

        // Define a dynamic rhythm with accelerando and subtle randomization
        let baseRhythmPattern: [TimeInterval] = [0.1, 0.15, 0.08, 0.12, 0.09, 0.14]
        let maxAcceleration: Double = 0.2 // total tempo speed-up (20%)
        let accelStep = maxAcceleration / Double(N)
        var cumulativeDelay: TimeInterval = 0

        // Melodic offsets per column
        let melodicOffsets: [Int] = [0, 2, 4, 5, 7, 9]

        // Stagger harmony voices by a small delay to avoid simultaneous onset
        //let harmonyStagger: TimeInterval = 0.02  // 20ms between voices
        //let harmonyIntervals = [0, 4, 7]

        // Build a cumulative delay to play each column fully staggered
        for x in 0..<N {
            // Compute interval with accelerando (speed-up) and random jitter
            let baseInterval = baseRhythmPattern[x % baseRhythmPattern.count]
            let accelerationFactor = 1.0 - accelStep * Double(x)  // intervals shorten over time
            let jitter = Double.random(in: -0.02...0.02)          // ±20ms variation
            let dynamicInterval = max(0.01, baseInterval * accelerationFactor + jitter)
            //let columnDelay = cumulativeDelay
            cumulativeDelay += dynamicInterval
            // Apply melodic offset per column
            let baseMelodyOffset = melodicOffsets[x % melodicOffsets.count]
            //let dynamicCode = (baseCode + x + baseMelodyOffset).clamped(to: 031...067)
            // --- Use CoreML-based filename logic via RedSpecial.shared ---
            // TODO: Implement CoreML WAV generation
            guard let encoder = self.prismDecoder else {
                print("⚠️ PrismDecoder not loaded")
                continue
            }
            do {
                // Map Color to CubeColor before calling buildPrismInput
                let uiColor = parameters.colors[x][0][0]
                let cubeColor: CubeColor
                switch uiColor {
                case .red:    cubeColor = .red
                case .yellow: cubeColor = .yellow
                case .blue:   cubeColor = .blue
                case .green:  cubeColor = .green
                case .orange: cubeColor = .orange
                default:      cubeColor = .white
                }
                // Build the two inputs for PrismDecoder using cubeColor (enum) instead of uiColor (SwiftUI.Color)
                let (maybeLatent, maybeInstrID) = self.buildPrismInput(
                    color: cubeColor,
                    octave: x,
                    countInColumn: x,
                    pickupOn: pickupSwitches["PS\(x)"] ?? false,
                    phaseOn: phaseSwitches["PhS\(x)"] ?? false,
                    volume: Float(velocity),
                    tone: Float(toneValueT),
                    ta: Float(taValue),
                    fret: Float(fret)
                )
                guard let latentInput = maybeLatent, let instrID = maybeInstrID else {
                    print("❌ Failed to build Prism input")
                    continue
                }
                // PrismDecoder expects *instrument_input* as a rank‑1 vector [1]
                let instrArray = try MLMultiArray(shape: [1], dataType: .float32)
                instrArray[0] = NSNumber(value: Float(instrID))
                let inputProvider = try MLDictionaryFeatureProvider(dictionary: [
                    "latent_input": MLFeatureValue(multiArray: latentInput),
                    "instrument_input": MLFeatureValue(multiArray: instrArray)
                ])
                // Run the PrismDecoder prediction
                let output = try encoder.prediction(from: inputProvider)
                guard let wavArray = output.featureValue(for: "Identity")?.multiArrayValue,
                      let pcmBuffer = SwitchViewModel.convertToPCMBuffer(from: wavArray) else {
                    print("❌ Failed to get PCM buffer from PrismDecoder")
                    continue
                }
                // Schedule and play as before
                let player = AVAudioPlayerNode()
                player.volume = 1.0
                let engine = AudioEngineManager.shared.engine
                engine.attach(player)
                engine.connect(player, to: engine.mainMixerNode, format: pcmBuffer.format)
                if !engine.outputConnectionPoints(for: engine.mainMixerNode, outputBus: 0).contains(where: { $0.node == engine.outputNode }) {
                    engine.connect(engine.mainMixerNode, to: engine.outputNode, format: pcmBuffer.format)
                }
                try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers, .defaultToSpeaker])
                try? AVAudioSession.sharedInstance().setActive(true)
                player.scheduleBuffer(pcmBuffer, at: nil, options: [], completionHandler: nil)
                player.play()
            } catch {
                print("❌ CoreML pipeline error: \(error)")
            }
            // (Optional: If you want to keep the rest of the harmony/SCAT/percussion scheduling, adapt them here as needed)
        }
    }

 

    /// Converts PrismDecoder output (1 × 16000 float32 @ 16 kHz) to a mono AVAudioPCMBuffer.
    /// The buffer is returned at 16 kHz; AVAudioEngine will resample to the device rate automatically.
    static func convertToPCMBuffer(from multiArray: MLMultiArray) -> AVAudioPCMBuffer? {
        // Ensure the MLMultiArray is Float32
        guard multiArray.dataType == .float32 else {
            print("❌ MLMultiArray is not Float32")
            return nil
        }

        let frameCount = AVAudioFrameCount(multiArray.count)

        // Create a 16 kHz, mono audio format
        guard
            let format = AVAudioFormat(standardFormatWithSampleRate: 16_000, channels: 1),
            let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)
        else {
            print("❌ Failed to create AVAudioPCMBuffer")
            return nil
        }

        buffer.frameLength = frameCount

        let sampleCount = Int(frameCount)
        var temp = [Float](repeating: 0, count: sampleCount)

        // 1) Copy the raw samples verbatim.
        //    PrismDecoder already emits audio in the −1…+1 range, so we do **not**
        //    apply the previous “*2 − 1” transform.  This avoids the huge DC offset
        //    and “ぎゃー” glitch that was caused by over‑scaling.
        for i in 0..<sampleCount {
            temp[i] = multiArray[i].floatValue
        }

        // 2) Estimate DC component only on *non‑silent* samples to avoid
        //    a large negative offset when most of the buffer is zeros.
        var dcSum: Float = 0
        var dcCount: Int = 0
        for v in temp where abs(v) > 1e-4 {
            dcSum   += v
            dcCount += 1
        }
        let dc = dcCount > 0 ? dcSum / Float(dcCount) : 0
        if abs(dc) > 1e-4 {
            for i in 0..<sampleCount {
                temp[i] -= dc
            }
        }

        // 3) Estimate peak and skip normalization if signal is near silence
        let peak = temp.map { abs($0) }.max() ?? 1.0
        let guardLevel: Float = 1e-3       // only normalize if peak above this
        let silenceThreshold: Float = 1e-2 // require a perceivable peak
        if peak > guardLevel && peak > silenceThreshold {
            for i in 0..<sampleCount {
                temp[i] /= peak
            }
        }
        // 4) Zero out residual tiny values to prevent noise
        let zeroThreshold: Float = 1e-4
        for i in 0..<sampleCount {
            if abs(temp[i]) < zeroThreshold {
                temp[i] = 0
            }
        }

        // 5) Copy the cleaned & normalised samples into the PCM buffer
        if let dst = buffer.floatChannelData?.pointee {
            for i in 0..<sampleCount {
                dst[i] = temp[i]
            }
        }
        // --- End of added processing ---

        return buffer
    }
    
    
    func handleInteraction(for id: String, translation: CGSize?, swipeVelocity: CGPoint?) {
        print("🔔 handleInteraction entered for id: \(id)")
        print("Handling interaction for \(id)")

        if id.hasPrefix("P1") || id.hasPrefix("P2") || id.hasPrefix("P3") {
            handleCubeRotation(id: id, translation: translation, swipeVelocity: swipeVelocity)
        } else if id.hasPrefix("PhS") || id.hasPrefix("PS") {
            handleSwitchToggle(id: id)
        } else if ["Repeat", "Shuffle", "PlayPause", "Next", "Prev", "Select"].contains(id) {
            handleMusicControl(id: id)
        } else if id == "HotSpace" {
            handleUndo()  // 全ステップ自動演奏＋リバース
            return
        }
    }

    
    func adjustVolume(by delta: CGFloat) {
        let change = Int(delta / 10 * 5)
        velocity = min(max(velocity + change, 0), 127)
        print("🎸 ボリューム更新: \(velocity)")
    }
    
    func adjustTone(by delta: CGFloat) {
        let change = Double(delta / 10)
        tone = min(max(tone + change, 0), 100)
        print("🎸 トーン更新: \(tone)")
    }
    
    func togglePickup(for id: String) {
        DispatchQueue.main.async {
            let current = self.pickupSwitches[id] ?? false
            self.pickupSwitches[id] = !current
            self.objectWillChange.send()
            print("🎸 \(id) ピックアップ切替: \(!current ? "ON" : "OFF")")
        }
    }
    
    func togglePhase(for id: String) {
        DispatchQueue.main.async {
            let current = self.phaseSwitches[id] ?? false
            self.phaseSwitches[id] = !current
            self.objectWillChange.send()
            print("🎸 \(id) フェーズ切替: \(!current ? "ON" : "OFF")")
        }
    }
    


    
    func setToggleState(for id: String, isOn: Bool) {
        if phaseSwitches.keys.contains(id) {
            phaseSwitches[id] = isOn
        } else {
            pickupSwitches[id] = isOn
        }
    }
    func handleCubeRotation(id: String, translation: CGSize?, swipeVelocity: CGPoint?) {
        let components = id.split(separator: "_")
        guard components.count == 3,
              let i = Int(components[1]),
              let j = Int(components[2]) else { return }

        if id.hasPrefix("P1") || id.hasPrefix("P2") {
            let zIndex: Int
            if id.hasPrefix("P1") {
                zIndex = 1
            } else if id.hasPrefix("P2") {
                zIndex = 4
            } else {
                zIndex = 0
            }

            if let translation = translation {
                let axis: Axis3D
                let sliceIndex: Int
                if id.hasPrefix("P2") {
                    let isHorizontal = abs(translation.width) > abs(translation.height)
                    axis = isHorizontal ? .y : .x
                    sliceIndex = isHorizontal ? j : i
                } else {
                    let isHorizontal = abs(translation.width) > abs(translation.height)
                    axis = isHorizontal ? .z : .x
                    sliceIndex = isHorizontal ? zIndex : i
                }
                // Track moved cells for Orbit logging
                let movedCells = cubeVM.cubeCells
                    .filter { cell in
                        let pos = cell.facelet.pos3D
                        switch axis {
                        case .x: return pos.x == sliceIndex
                        case .y: return pos.y == sliceIndex
                        case .z: return pos.z == sliceIndex
                        }
                    }
                    .map { $0.facelet.pos3D }

                let speed = swipeVelocity.map { sqrt($0.x * $0.x + $0.y * $0.y) } ?? 300.0
                let move = Move(axis: axis, sliceIndex: sliceIndex, clockwise: true, movedCells: movedCells, timestamp: Date(), swipeVelocity: speed)
                self.mappingModel.cubicModel.moveHistory.append(move)

                let selectedPos = Pos3D(x: i, y: j, z: zIndex)
                cubeVM.rotateSlice(for: selectedPos, axis: axis, sliceIndex: sliceIndex, clockwise: true)

                let cubeCells = mappingModel.cubicModel.cubeCells

                // Sort once into a local variable to simplify type-checking
                let sortedCells = cubeCells.sorted { cell1, cell2 in
                    let g1 = cell1.facelet.grid.toArray()
                    let g2 = cell2.facelet.grid.toArray()
                    if g1[2] != g2[2] { return g1[2] < g2[2] }
                    if g1[1] != g2[1] { return g1[1] < g2[1] }
                    return g1[0] < g2[0]
                }

                // ScrambleStep として色・SCAT・duration・コントロール状態を一括記録
                let colors = sortedCells.map { $0.colorName }
                let scatSymbols: [(grid: [Int], scat: String)] = sortedCells.map {
                    ($0.facelet.grid.toArray(), $0.scatSymbol ?? "-")
                }
                let duration = ScrambleStep.duration(from: speed)
                let state = RedSpecialState(
                    ps1: self.ps1, ps2: self.ps2, ps3: self.ps3,
                    phs1: self.phs1, phs2: self.phs2, phs3: self.phs3,
                    ta: self.ta, tone: self.tone, volume: self.volume,
                    tremoloAngle: self.tremoloAngle,
                    directionHint: self.directionHint,
                    dominantPlayer: self.dominantPlayer,
                    scatSymbol: "-"
                )
                self.scrambleHistory.append(ScrambleStep(colors: colors, scatSymbols: scatSymbols, duration: duration, redSpecialState: state))
            }

            cubeVM.objectWillChange.send()
            DispatchQueue.main.async {
                self.mappingModel.cubeCellsDictionary = self.mappingModel.cubicModel.cubeCells.reduce(into: [:]) { dict, cell in
                    dict[cell.facelet.pos3D] = cell
                }
            }
            NotificationCenter.default.post(name: .updateCubeCellsView, object: nil)
        } else if id.hasPrefix("P3") {
            let face: CubeFace = .top  // P3 is mapped to top face
            if let translation = translation {
                let isHorizontal = abs(translation.width) > abs(translation.height)
                let axis: Axis3D
                let sliceIndex: Int
                // Simplified logic for .top face only
                if face == .top || face == .bottom {
                    axis = isHorizontal ? .z : .x
                    sliceIndex = isHorizontal ? j : i
                } else {
                    axis = .x
                    sliceIndex = i
                }
                // Track moved cells for Orbit logging
                let movedCells = cubeVM.cubeCells
                    .filter { cell in
                        let pos = cell.facelet.pos3D
                        switch axis {
                        case .x: return pos.x == sliceIndex
                        case .y: return pos.y == sliceIndex
                        case .z: return pos.z == sliceIndex
                        }
                    }
                    .map { $0.facelet.pos3D }

                let speed = swipeVelocity.map { sqrt($0.x * $0.x + $0.y * $0.y) } ?? 300.0
                let move = Move(axis: axis, sliceIndex: sliceIndex, clockwise: true, movedCells: movedCells, timestamp: Date(), swipeVelocity: speed)
                self.mappingModel.cubicModel.moveHistory.append(move)
                let selectedPos = Pos3D(x: i, y: j, z: 5)
                cubeVM.rotateSlice(for: selectedPos, axis: axis, sliceIndex: sliceIndex, clockwise: true)

                let cubeCells = mappingModel.cubicModel.cubeCells
                let sortedCells = cubeCells.sorted { cell1, cell2 in
                    let g1 = cell1.facelet.grid.toArray()
                    let g2 = cell2.facelet.grid.toArray()
                    if g1[2] != g2[2] { return g1[2] < g2[2] }
                    if g1[1] != g2[1] { return g1[1] < g2[1] }
                    return g1[0] < g2[0]
                }

                let colors = sortedCells.map { $0.colorName }
                let scatSymbols: [(grid: [Int], scat: String)] = sortedCells.map {
                    ($0.facelet.grid.toArray(), $0.scatSymbol ?? "-")
                }
                let duration = ScrambleStep.duration(from: speed)
                let state = RedSpecialState(
                    ps1: self.ps1, ps2: self.ps2, ps3: self.ps3,
                    phs1: self.phs1, phs2: self.phs2, phs3: self.phs3,
                    ta: self.ta, tone: self.tone, volume: self.volume,
                    tremoloAngle: self.tremoloAngle,
                    directionHint: self.directionHint,
                    dominantPlayer: self.dominantPlayer,
                    scatSymbol: "-"
                )
                self.scrambleHistory.append(ScrambleStep(colors: colors, scatSymbols: scatSymbols, duration: duration, redSpecialState: state))
            }

            cubeVM.objectWillChange.send()
            DispatchQueue.main.async {
                self.mappingModel.cubeCellsDictionary = self.mappingModel.cubicModel.cubeCells.reduce(into: [:]) { dict, cell in
                    dict[cell.facelet.pos3D] = cell
                }
            }
            NotificationCenter.default.post(name: .updateCubeCellsView, object: nil)
        }
    }

    func handleSwitchToggle(id: String) {
        if id.hasPrefix("PhS") {
            phaseSwitches[id] = !(phaseSwitches[id] ?? false)
            print("Phase switch \(id) toggled to \(phaseSwitches[id]!)")
        } else if id.hasPrefix("PS") {
            pickupSwitches[id] = !(pickupSwitches[id] ?? false)
            print("Pickup switch \(id) toggled to \(pickupSwitches[id]!)")
        }
    }

    func handleMusicControl(id: String) {
        switch id {
        case "Repeat":
            MusicManager.shared.isRepeatEnabled.toggle()
            print("Repeat toggled to \(MusicManager.shared.isRepeatEnabled)")
        case "Shuffle":
            MusicManager.shared.isShuffleEnabled.toggle()
            print("Shuffle toggled to \(MusicManager.shared.isShuffleEnabled)")
        case "PlayPause":
            MusicManager.shared.togglePlayPause()
            print("▶️ PlayPause トグル実行")
        case "Next":
            MusicManager.shared.playNextTrack()
            print("⏭️ 次の曲へ")
        case "Prev":
            MusicManager.shared.playPreviousTrack()
            print("⏮️ 前の曲へ")
        case "Select":
            MusicManager.shared.promptMusicSourceSelection()
            print("🧭 ソース選択プロンプト表示")
        default:
            break
        }
    }

    func handleUndo() {
        print("🔥 自動演奏開始（全ステップリバース）")
        guard !scrambleHistory.isEmpty else {
            print("⚠️ scrambleHistory が空です")
            return
        }

        let steps = scrambleHistory.reversed()
        let moves = mappingModel.cubicModel.moveHistory.reversed()
        let moveArray = Array(moves)

        var cumulativeDelay: TimeInterval = 0

        for (i, step) in steps.enumerated() {
            let delay = cumulativeDelay

            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                // 音楽再生
                self.playStep(step)

                // キューブをリバース
                if i < moveArray.count {
                    let move = moveArray[i]
                    self.cubeVM.rotateSlice(
                        for: Pos3D(x: 0, y: 0, z: 0),
                        axis: move.axis,
                        sliceIndex: move.sliceIndex,
                        clockwise: !move.clockwise
                    )
                    NotificationCenter.default.post(name: .updateCubeCellsView, object: nil)
                }
            }

            cumulativeDelay += step.duration
        }

        // 全ステップ完了後にクリア
        DispatchQueue.main.asyncAfter(deadline: .now() + cumulativeDelay) {
            self.mappingModel.cubicModel.moveHistory.removeAll()
            self.scrambleHistory.removeAll()
            print("✅ 演奏完了・履歴クリア")
        }
    }
    

    // StereoPan enum for panning
    enum StereoPan {
        case left, center, right
    }


    /// Converts a mono AVAudioPCMBuffer to stereo, with panning (left, center, right).
    static func convertMonoToStereo(_ monoBuffer: AVAudioPCMBuffer, pan: StereoPan) -> AVAudioPCMBuffer? {
        let frameLength = monoBuffer.frameLength
        let format = AVAudioFormat(standardFormatWithSampleRate: monoBuffer.format.sampleRate, channels: 2)!
        guard let stereoBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameLength) else {
            return nil
        }

        stereoBuffer.frameLength = frameLength

        guard let monoDataPtr = monoBuffer.floatChannelData else { return nil }
        guard let stereoDataLPtr = stereoBuffer.floatChannelData?[0], let stereoDataRPtr = stereoBuffer.floatChannelData?[1] else { return nil }
        let monoData = monoDataPtr[0]
        let stereoDataL = stereoDataLPtr
        let stereoDataR = stereoDataRPtr

        for i in 0..<Int(frameLength) {
            switch pan {
            case .left:
                stereoDataL[i] = monoData[i]
                stereoDataR[i] = 0
            case .center:
                stereoDataL[i] = monoData[i]
                stereoDataR[i] = monoData[i]
            case .right:
                stereoDataL[i] = 0
                stereoDataR[i] = monoData[i]
            }
        }

        return stereoBuffer
    }

}

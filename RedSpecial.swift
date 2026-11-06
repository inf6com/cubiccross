
import simd

// MARK: - RedSpecialState struct
struct RedSpecialState {
    var ps1: Bool
    var ps2: Bool
    var ps3: Bool
    var phs1: Bool
    var phs2: Bool
    var phs3: Bool
    var ta: Bool
    var tone: Double
    var volume: Double
    var tremoloAngle: Double
    var directionHint: SIMD2<Double>
    var dominantPlayer: String
    var scatSymbol: String
}

// MARK: - SCATVoice singleton class for SCAT symbol playback
class SCATVoice {
    static let shared = SCATVoice()

    func play(symbol: String) {
        print("🎤 SCAT再生: \(symbol)")
        // 実際のサウンド再生処理をここに追加
        // 例: SCATVoiceモデルを使う場合はここでモデル推論・再生を実装
    }
}


import SwiftUI
import AVFoundation
import CoreML
import MusicKit
import CoreGraphics
import Foundation
import Combine
import QuartzCore
/// Encodes AudioMetadata into Core ML inputs
struct PrismInputEncoder {
    /// Build the combined latent_input array dynamically based on InstrumentDB metadata
    static func latentInput(from metadata: AudioMetadata) throws -> MLMultiArray {
        // Calculate total feature count
        let pitchCount = 1
        let velocityCount = 1
        let sourceCount = InstrumentDB.sources.count
        let familyCount = InstrumentDB.families.count
        let qualitiesCount = InstrumentDB.qualities.count
        let total = pitchCount + velocityCount + sourceCount + familyCount + qualitiesCount
        // Create MLMultiArray of shape [1, total]
        let mlArray = try MLMultiArray(shape: [1, NSNumber(value: total)], dataType: .float32)
        var idx = 0
        // Normalized pitch and velocity
        mlArray[[0, NSNumber(value: idx)]] = NSNumber(value: metadata.pitch); idx += 1
        mlArray[[0, NSNumber(value: idx)]] = NSNumber(value: metadata.velocity); idx += 1
        // One-hot source
        for i in 0..<sourceCount {
            let v: Float = (metadata.instrumentSource == i) ? 1 : 0
            mlArray[[0, NSNumber(value: idx)]] = NSNumber(value: v); idx += 1
        }
        // One-hot family
        for i in 0..<familyCount {
            let v: Float = (metadata.instrumentFamily == i) ? 1 : 0
            mlArray[[0, NSNumber(value: idx)]] = NSNumber(value: v); idx += 1
        }
        // Qualities vector
        for q in metadata.qualities {
            mlArray[[0, NSNumber(value: idx)]] = NSNumber(value: q); idx += 1
        }
        return mlArray
    }
    /// Build the single-element instrument_input array
    static func instrumentInput(from id: Int) throws -> MLMultiArray {
        let mlArray = try MLMultiArray(shape: [1], dataType: .float32)
        mlArray[0] = NSNumber(value: Float(id))
        return mlArray
    }
}

/// Centralised database for Prism instrument & quality metadata
struct InstrumentDB {
    /// 0 = acoustic, 1 = electronic, 2 = synthetic
    static let sources: [Int] = [0, 1, 2]

    /// 0 … 10   (bass, brass, flute, guitar, keyboard, mallet, organ, reed, string, synth_lead, vocal)
    static let families: [Int] = Array(0...10)

    /// Instrument prefix strings (kept in the same order as before)
    static let prefixes: [String] = [
        "bass_acoustic", "bass_electronic", "bass_synthetic",
        "brass_acoustic", "brass_electronic",
        "flute_acoustic", "flute_electronic", "flute_synthetic",
        "guitar_acoustic", "guitar_electronic", "guitar_synthetic",
        "keyboard_acoustic", "keyboard_electronic", "keyboard_synthetic",
        "mallet_acoustic", "mallet_electronic", "mallet_synthetic",
        "organ_acoustic", "organ_electronic",
        "reed_acoustic", "reed_electronic", "reed_synthetic",
        "string_acoustic", "string_electronic",
        "synth_lead_synthetic",
        "vocal_acoustic", "vocal_electronic", "vocal_synthetic"
    ]

    /// Existing `instrumentSuffixesByPrefix` dictionary literal (verbatim copy)
    static let suffixesByPrefix: [String: [String]] = [
        // --- copy of the original dictionary ---
        "bass_acoustic": [
            "000"
        ],
        "bass_electronic": [
            "000","001","002","003","004","005","006","007","008","009",
            "010","011","012","013","014","015","016","017","019","020",
            "021","022","023","024","026","028","029","030","031","032",
            "033","034","035","036","037","038","039"
        ],
        "bass_synthetic": [
            "000","001","002","003","004","005","006","007","008","010",
            "011","012","013","014","015","016","017","018","019","020",
            "021","022","023","024","025","026","027","028","029","030",
            "031","032","035","036","037","038","039","040","041","042",
            "043","044","045","046","047","048","049","050","051","052",
            "053","054","055","056","057","058","059","060","061","062",
            "063","064","065","066","067","069","070","071","072","073",
            "074","075","076","077","078","079","080","081","082","083",
            "084","085","086","087","088","089","090","091","092","093",
            "094","095","096","097","099","100","101","102","103","104",
            "105","106","107","108","109","110","111","112","113","114",
            "115","116","117","118","119","120","121","122","123","124",
            "125","126","127","128","129","130","131","132","133","136",
            "137","138","139","140","141","142","143","144","145","146",
            "147","148","149","150","151","152"
        ],
        "brass_acoustic": [
            "000","001","002","003","004","005","007","008","009","010",
            "011","012","013","014","017","018","019","020","021","022",
            "023","024","025","026","027","028","029","030","031","032",
            "033","034","035","036","037","038","039","040","041","042",
            "043","044","045","047","048","049","050","051","052","053",
            "054","055","056","057","058","060","061","062","063","064",
            "065","066"
        ],
        "brass_electronic": [
            "000","001"
        ],
        "flute_acoustic": [
            "000","001","003","004","005","006","007","008","009","010",
            "011","012","013","014","015","016","017","018","019","020",
            "021","022","023","024","025","026","027","028","029","030",
            "031","032","033","034","035"
        ],
        "flute_electronic": [
            "000"
        ],
        "flute_synthetic": [
            "001","002","003","004","005","006","007"
        ],
        "guitar_acoustic": [
            "000","001","002","003","004","005","006","007","008","009",
            "011","012","013","016","017","018","019","020","022","023",
            "024","025","026","027","028","029","031","032","033","034",
            "035","036"
        ],
        "guitar_electronic": [
            "000","001","002","003","004","005","006","007","008","009",
            "010","011","012","013","014","015","016","017","018","019",
            "020","021","023","024","025","026","027","029","030","031",
            "032","033","034","035","036","037","038","039","040","041",
            "042","043","044","045","046"
        ],
        "guitar_synthetic": [
            "000","001","002","003","004","005","006","007","008","009",
            "010","011","012"
        ],
        "keyboard_acoustic": [
            "000","001","002","003","005","006","007","008","009","010",
            "011","012","013","014","015","016","017","018","019","020"
        ],
        "keyboard_electronic": [
            "000","004","005","006","007","008","009","010","011","012",
            "013","014","015","016","017","018","019","020","021","022",
            "023","024","025","026","027","028","029","030","031","032",
            "033","034","035","036","037","038","039","040","041","042",
            "043","044","045","046","047","048","049","050","051","052",
            "053","054","055","056","057","058","059","060","061","062",
            "063","064","065","066","067","068","070","071","072","073",
            "074","075","076","077","079","080","081","082","083","084",
            "085","086","087","088","089","090","091","092","093","094",
            "095","096","097","099","100","101","102","103","104","105",
            "106","107","108","109","110","111"
        ],
        "keyboard_synthetic": [
            "001","002","003","004","005","006","007","008","009","010",
            "011","012"
        ],
        "mallet_acoustic": [
            "000","001","002","003","004","005","006","007","008","009",
            "010","011","012","013","014","015","016","017","018","019",
            "020","021","022","023","024","025","026","027","028","029",
            "030","031","032","033","034","035","036","037","038","039",
            "040","041","042","043","044","045","046","048","049","050",
            "051","052","053","054","055","057","058","059","060","061",
            "063","064","065","066","067","068","069","070","071","072",
            "073","074","075","076","077","078","079","080"
        ],
        "mallet_electronic": [
            "000","001","002","003","004","005","006","007","008","009",
            "010","011","012","013"
        ],
        "mallet_synthetic": [
            "000","001","002","003","004"
        ],
        "organ_acoustic": [
            "000","001","002","003"
        ],
        "organ_electronic": [
            "000","002","003","004","005","006","008","009","010","011",
            "012","013","014","015","016","017","018","019","020","021",
            "022","023","024","025","026","027","029","030","031","032",
            "033","034","035","036","037","038","039","040","041","042",
            "043","044","045","046","047","048","049","050","051","052",
            "053","054","055","056","058","059","060","061","062","063",
            "064","065","066","067","068","069","070","071","072","073",
            "074","075","076","077","078","079","080","081","082","083",
            "084","085","086","087","088","089","090","091","092","093",
            "094","095","096","097","098","099","100","101","102","103",
            "105","106","107","108","109","110","111","112","114","115",
            "116","117","118","119","120","121","122","123","124","125",
            "126","127","128","129"
        ],
        "reed_acoustic": [
            "000","001","002","003","004","005","006","007","008","009",
            "010","012","013","014","015","016","017","019","020","021",
            "022","024","025","026","027","028","029","030","031","032",
            "033","034","035","036","038","039","040","041","042","043",
            "044","045","046","047","048","049","050","051","052","053",
            "054","055","056","057","058","059","060","061"
        ],
        "reed_electronic": [
            "000"
        ],
        "reed_synthetic": [
            "000","001"
        ],
        "string_acoustic": [
            "000","001","002","003","004","005","006","007","008","009",
            "010","011","013","015","016","017","018","019","020","021",
            "022","023","024","025","026","027","028","029","030","031",
            "032","033","034","035","036","037","038","039","040","041",
            "042","043","044","045","046","047","048","049","050","051",
            "052","053","054","055","058","059","060","061","062","063",
            "064","065","066","067","068","069","070","072","073","074",
            "075","076","077","078","079","081","082","083","084","085",
            "086","087","088","089","090"
        ],
        "string_electronic": [
            "000","001"
        ],
        "synth_lead_synthetic": [
            "000","001","002","003","004","005","006","007","008","009",
            "010","011","012"
        ],
        "vocal_acoustic": [
            "001","002","003","004","005","006","007","008","009","010",
            "011","012","013","014","015","016","017","018","019","020",
            "021","022","023","024","025","026","027","028","029"
        ],
        "vocal_electronic": [
            "000","001","002","003"
        ],
        "vocal_synthetic": [
            "000","001","002","004","005","006","007","008","009","010",
            "011","012","013","014","015"
        ]
    ]

    /// Flattened list of "<prefix>_<suffix>" full instrument identifiers
    static let instrumentStrs: [String] = prefixes.flatMap { p in
        suffixesByPrefix[p, default: []].map { "\(p)_\($0)" }
    }

    /// 10‑way quality labels
    static let qualities: [String] = [
        "bright", "dark", "distortion", "fast_decay", "long_release",
        "multiphonic", "nonlinear_env", "percussive", "reverb", "tempo-synced"
    ]
}






// MARK: - RedSpecial AI Adjustment & Color Group Analysis
extension SwitchViewModel {
    
    
    // MARK: - persistent audio objects (avoid de‑init before sound finishes)
    private static let sharedAudio: (engine: AVAudioEngine, player: AVAudioPlayerNode) = {
        let engine = AVAudioEngine()
        let player = AVAudioPlayerNode()
        engine.attach(player)
        let outputFormat = engine.mainMixerNode.outputFormat(forBus: 0)
        engine.connect(player, to: engine.mainMixerNode, format: outputFormat)
        // Connect mainMixerNode to outputNode (ensure output connection)
        engine.connect(engine.mainMixerNode, to: engine.outputNode, format: nil)
        // Configure AVAudioSession for playback even in Silent mode
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [])
            try session.setActive(true)
        } catch {
            print("⚠️ AVAudioSession setup failed: \(error)")
        }
        do {
            try engine.start()
        } catch {
            print("⚠️ AVAudioEngine start 失敗 (init): \(error)")
        }
        return (engine, player)
    }()
    
    
    
    
    /// Maps the instrument string (e.g. "guitar_electronic_023") to its Prism **source** index
    /// 0 = acoustic, 1 = electronic, 2 = synthetic
    private func instrumentSourceIndex(_ instStr: String) -> Int {
        if instStr.contains("_acoustic")   { return 0 }
        if instStr.contains("_electronic") { return 1 }
        return 2  // fallback = synthetic
    }

    /// Maps the instrument string to its Prism **family** index (see `instrumentFamilies` order)
    /// 0:bass 1:brass 2:flute 3:guitar 4:keyboard 5:mallet 6:organ 7:reed 8:string 9:synth_lead 10:vocal
    private func instrumentFamilyIndex(_ instStr: String) -> Int {
        if instStr.hasPrefix("bass_")         { return 0 }
        if instStr.hasPrefix("brass_")        { return 1 }
        if instStr.hasPrefix("flute_")        { return 2 }
        if instStr.hasPrefix("guitar_")       { return 3 }
        if instStr.hasPrefix("keyboard_")     { return 4 }
        if instStr.hasPrefix("mallet_")       { return 5 }
        if instStr.hasPrefix("organ_")        { return 6 }
        if instStr.hasPrefix("reed_")         { return 7 }
        if instStr.hasPrefix("string_")       { return 8 }
        if instStr.hasPrefix("synth_lead_")   { return 9 }
        return 10  // vocal / unknown
    }
    /// Plays multiple buffers at once, applying pitch shifts and EQ according to the provided semitone pattern.
    private func playBuffersWithPitch(_ buffers: [AVAudioPCMBuffer], semitonePattern: [Float]) {
        guard !buffers.isEmpty else {
            print("🔇 No buffers to play.")
            return
        }
        let (engine, _) = Self.sharedAudio
        var players: [AVAudioPlayerNode] = []
        let centsPerSemitone: Float = 100

        for (index, buffer) in buffers.enumerated() {
            let player = AVAudioPlayerNode()
            let pitchNode = AVAudioUnitTimePitch()
            // Attach nodes
            engine.attach(player)
            engine.attach(pitchNode)
            // Prefer the higher‑quality spectral time‑stretching algorithm when the SDK supports it
            #if compiler(>=5.5)
            if #available(iOS 15.0, macOS 12.0, tvOS 15.0, *) {
                // Use higher‑quality spectral algorithm when the property exists
                if player.responds(to: Selector(("setTimePitchAlgorithm:"))) {
                    player.setValue(AVAudioTimePitchAlgorithm.spectral.rawValue, forKey: "timePitchAlgorithm")
                }
            }
            #endif
            // Insert and configure AVAudioUnitEQ for guitar-style filtering
            let eq = AVAudioUnitEQ(numberOfBands: 4)
            // High-pass band (bands[0])
            let highPassBand = eq.bands[0]
            highPassBand.filterType = .highPass
            highPassBand.frequency = 120
            highPassBand.bandwidth = 0.707 // 1-pole slope
            highPassBand.gain = 0.0
            highPassBand.bypass = false
            // Parametric band (bands[1]) -- pick/pluck presence
            let parametricBand = eq.bands[1]
            parametricBand.filterType = .parametric
            parametricBand.frequency = 3000
            parametricBand.bandwidth = 0.8
            parametricBand.gain = 4.0
            parametricBand.bypass = false
            // High-shelf band (bands[2])
            let highshelfBand = eq.bands[2]
            highshelfBand.filterType = .highShelf
            highshelfBand.frequency = 5500
            highshelfBand.bandwidth = 0.6
            highshelfBand.gain = -2.0
            highshelfBand.bypass = false
            // Low-pass band (bands[3]) -- allow more harmonics
            let lowPassBand = eq.bands[3]
            lowPassBand.filterType = .lowPass
            lowPassBand.frequency = 6500
            lowPassBand.bandwidth = 0.7
            lowPassBand.gain = 0.0
            lowPassBand.bypass = false
            engine.attach(eq)
            // --- Insert gentle overdrive to restore guitar bite ---
            let distortion = AVAudioUnitDistortion()
            distortion.loadFactoryPreset(.multiDistortedFunk)
            distortion.preGain = -6     // dB, subtle
            distortion.wetDryMix = 0    // %
            distortion.bypass = true
            engine.attach(distortion)
            // --- Insert reverb node after distortion ---
            let reverb = AVAudioUnitReverb()
            reverb.loadFactoryPreset(.mediumHall)
            reverb.wetDryMix = 30
            engine.attach(reverb)
            // Configure pitch in cents
            let semitone = semitonePattern[index]
            pitchNode.pitch = semitone * centsPerSemitone
            // Connect player → pitch → eq → distortion → reverb → mixer
            engine.connect(player, to: pitchNode, format: buffer.format)
            engine.connect(pitchNode, to: eq, format: buffer.format)
            engine.connect(eq, to: distortion, format: buffer.format)
            engine.connect(distortion, to: reverb, format: buffer.format)
            engine.connect(reverb, to: engine.mainMixerNode, format: buffer.format)

            // --- Truncate buffer with *humanised* note lengths ---
            // ベースは「偶数＝ロング／奇数＝ショート」だが、±15 % の揺らぎを加えて機械感を低減
            let baseLong:  Double = 0.55   // ≈550 ms
            let baseShort: Double = 0.28   // ≈280 ms
            let jitterFactor = 1.0 + Double.random(in: -0.15...0.10)  // -15 % … +10 %
            let durationSec = ((index % 2) == 0 ? baseLong : baseShort) * jitterFactor
            let maxFrames = AVAudioFramePosition(buffer.format.sampleRate * durationSec)
            buffer.frameLength = min(buffer.frameLength, AVAudioFrameCount(maxFrames))
            // Apply per-note envelope: fade in/out
            let channelCount = Int(buffer.format.channelCount)
            let totalFrames = Int(buffer.frameLength)
            let fadeFrames = max(1, totalFrames / 64)  // tighter, punchier attack/release
            for channel in 0..<channelCount {
                let data = buffer.floatChannelData![channel]
                // Fade in
                for frame in 0..<fadeFrames {
                    let gain = powf(Float(frame) / Float(fadeFrames), 0.35)
                    data[frame] *= gain
                }
                // Fade out
                for frame in 0..<fadeFrames {
                    let idx = totalFrames - 1 - frame
                    let gain = powf(Float(frame) / Float(fadeFrames), 0.35)
                    data[idx] *= (1.0 - gain)
                }
            }
            // Increase overall volume
            let globalGain: Float = 1.5   // boosted for higher output level
            for channel in 0..<channelCount {
                let data = buffer.floatChannelData![channel]
                let frames = Int(buffer.frameLength)
                for i in 0..<frames {
                    data[i] *= globalGain
                }
            }
            // Debug log: scheduling buffer
            print("🎼 Scheduling buffer, frameLength: \(buffer.frameLength)")
            let previewSamples = (0..<10).map { buffer.floatChannelData!.pointee[$0] }
            print("🔍 Buffer preview: \(previewSamples)")
            // Schedule playback with completion handler and debug prints
            player.scheduleBuffer(buffer, at: nil, options: []) {
                print("✅ Finished playing buffer")
            }
            print("🎬 Scheduled buffer")
            players.append(player)
        }

        // Optional: Keep a strong reference to the active players to avoid early deallocation
        self.activePlayers = players

        // No need to configure AVAudioSession or connect main mixer to output node (already handled by shared engine)

        DispatchQueue.main.async {
            // --- Ensure AVAudioEngine is running ---
            engine.prepare()
            do {
                try engine.start()
            } catch {
                print("⚠️ Engine failed to start: \(error)")
            }

            // --- Ensure correct audio output connection ---
            engine.connect(engine.mainMixerNode, to: engine.outputNode, format: engine.mainMixerNode.outputFormat(forBus: 0))

            // --- Redundant but safe reactivation of AVAudioSession ---
            do {
                let session = AVAudioSession.sharedInstance()
                try session.setCategory(.playback, options: [.mixWithOthers, .duckOthers])
                try session.setActive(true)
                try session.overrideOutputAudioPort(.speaker)
            } catch {
                print("⚠️ AVAudioSession reactivation failed: \(error)")
            }

            print("🔈 Output route: \(AVAudioSession.sharedInstance().currentRoute.outputs)")

            engine.mainMixerNode.outputVolume = 1.0
            for player in players {
                print("▶️ Called play()")
                player.play()
                print("▶️ Called play()")
            }
            print("▶️ playBuffersWithPitch: started playback for \(players.count) buffers")
            print("🧪 AVAudioEngine isRunning: \(engine.isRunning)")
            print("🧪 Output format: \(engine.outputNode.outputFormat(forBus: 0))")
            print("🧪 Mixer format: \(engine.mainMixerNode.outputFormat(forBus: 0))")
        }
        // Do not stop the shared engine after playback; let it continue running.
    }
    /// Call this to replay scramble history step by step using .onReceive.

    
    /// スクランブル1ステップを演奏する。ScrambleStep に色・SCAT・コントロール状態が内包されている。
    func playStep(_ step: ScrambleStep) {
        print("🔥【PLAYSTEP】playStep called, duration=\(step.duration)s")
        let work = DispatchWorkItem {
            let colors = step.colors
            guard colors.count >= 108 else {
                print("❌ Step colors count \(colors.count), expected at least 108.")
                return
            }
            let totalCount = colors.count
            let half = min(108, totalCount)
            let firstBlock = Array(colors.prefix(half))
            let secondBlock = Array(colors.suffix(half))
            let trimmed = firstBlock.contains(where: { $0.lowercased() == "yellow" }) ? firstBlock : secondBlock

            let scatStep = step.scatSymbols
            let rs = step.redSpecialState

            // Derive grid dimensions dynamically
            let tracksPerColumn = 6   // number of rows per column; adjust if grid size changes
            let columns = trimmed.count / tracksPerColumn

            // Precompute audioMetaData: [row][col] -> AudioMetadata
            var audioMetaData: [[AudioMetadata]] = Array(
                repeating: Array(repeating: AudioMetadata(
                    pitch: 0, velocity: 64, instrument: 0, instrumentFamily: 0, instrumentSource: 0, qualities: Array(repeating: 0, count: InstrumentDB.qualities.count)
                ), count: columns),
                count: tracksPerColumn
            )
            for col in 0..<columns {
                for row in 0..<tracksPerColumn {
                    let idx = col * tracksPerColumn + row
                    let colorName = trimmed[idx].lowercased()
                    let colorIndex: Int
                    switch colorName {
                    case "red":    colorIndex = 0
                    case "yellow": colorIndex = 1
                    case "blue":   colorIndex = 2
                    case "green":  colorIndex = 3
                    case "orange": colorIndex = 4
                    default:       colorIndex = 5  // white/unknown
                    }
                    // Compose instrumentStr based on colorIndex, fallback if out of bounds
                    let instrumentStr: String
                    if colorIndex < InstrumentDB.instrumentStrs.count {
                        instrumentStr = InstrumentDB.instrumentStrs[colorIndex]
                    } else {
                        instrumentStr = InstrumentDB.instrumentStrs.first ?? ""
                    }
                    // Use the correct index from InstrumentDB.instrumentStrs
                    let instrumentID = InstrumentDB.instrumentStrs.firstIndex(of: instrumentStr) ?? 0
                    let instrumentFamily = InstrumentDB.families[colorIndex]
                    let instrumentSource = InstrumentDB.sources[colorIndex % InstrumentDB.sources.count]
                    // Map rows to a pentatonic rock scale, lower for vocals (red)
                    let pentatonic: [Float] = [0, 3, 5, 7, 10, 12]
                    let baseMIDINote: Float
                    if colorIndex == 0 { // red = vocal
                        baseMIDINote = 40  // lower octave for vocals
                    } else {
                        baseMIDINote = 48  // C3 for others
                    }
                    let basePitch: Float = baseMIDINote + pentatonic[row % pentatonic.count]
                    let velocity: Float = (colorIndex == 0 || colorIndex == 1) ? 100.0 : 30.0
                    let qualities: [Float] = Array(repeating: 0, count: InstrumentDB.qualities.count)
                    audioMetaData[row][col] = AudioMetadata(
                        pitch: basePitch,
                        velocity: velocity,
                        instrument: instrumentID,
                        instrumentFamily: instrumentFamily,
                        instrumentSource: instrumentSource,
                        qualities: qualities
                    )
                }
            }

            for col in 0..<columns {
                let startIdx = col * tracksPerColumn
                let endIdx = startIdx + tracksPerColumn
                let trackSlice = Array(trimmed[startIdx..<endIdx])
                print("🗂 trackSlice for column \(col): \(trackSlice)")
                var buffers: [AVAudioPCMBuffer] = []
                // Compute pan per row dynamically based on number of tracks
                let panPositions: [StereoPan] = (0..<tracksPerColumn).map { row in
                    let segment = tracksPerColumn / 3
                    if row < segment {
                        return .left
                    } else if row < 2 * segment {
                        return .center
                    } else {
                        return .right
                    }
                }
            for (trackIndex, colorName) in trackSlice.enumerated() {
                // Map colorName string to CubeColor
                let colorLower = colorName.lowercased()
                let cubeColor: CubeColor
                switch colorLower {
                case "red":    cubeColor = .red
                case "yellow": cubeColor = .yellow
                case "blue":   cubeColor = .blue
                case "green":  cubeColor = .green
                case "orange": cubeColor = .orange
                default:       cubeColor = .white
                }
                // SCAT 記号を取得（scatSymbols は ScrambleStep に内包）
                let scatSymbol: String = {
                    let idx = startIdx + trackIndex
                    guard idx < scatStep.count else { return "-" }
                    return scatStep[idx].scat
                }()
                if scatSymbol != "-" {
                    // Play SCAT via SCATVoice model
                    // Build pure-SCAT input and run SCATVoice.mlmodel
                    do {
                        let provider = try MLDictionaryFeatureProvider(dictionary: [
                            "scat_input": MLFeatureValue(string: scatSymbol)
                        ])
                        let scatModel = try Self.loadSoundModel(named: "SCATVoice")
                        let output = try scatModel.prediction(from: provider)
                        guard let scatArray = output.featureValue(for: "Identity")?.multiArrayValue,
                              let scatBuffer = SwitchViewModel.convertToPCMBuffer(from: scatArray) else {
                            print("❌ SCATVoice output conversion failed")
                            continue
                        }

                        let scatPlayer = AVAudioPlayerNode()
                        let engine = AudioEngineManager.shared.engine
                        engine.attach(scatPlayer)
                        engine.connect(scatPlayer, to: engine.mainMixerNode, format: scatBuffer.format)
                        scatPlayer.scheduleBuffer(scatBuffer, at: nil, options: [], completionHandler: nil)
                        scatPlayer.play()
                    } catch {
                        print("❌ SCATVoice prediction failed: \(error.localizedDescription)")
                    }
                }
                    // --- Play all tracks (remove yellow-only restriction) ---
                    // guard cubeColor == .yellow else { continue }
                    // Use actual instance properties for ta and fret
                    // white = 無音。発音しない。
                    if cubeColor == .white { continue }

                    // スクランブル時のコントロール状態を使用して音色を決定
                    let (maybeLatent, maybeInstrID) = self.buildPrismInput(
                        color: cubeColor,
                        octave: col,
                        countInColumn: trackIndex,
                        pickupOn: trackIndex == 0 ? rs.ps1 : (trackIndex == 1 ? rs.ps2 : rs.ps3),
                        phaseOn: trackIndex == 0 ? rs.phs1 : (trackIndex == 1 ? rs.phs2 : rs.phs3),
                        volume: Float(rs.volume),
                        tone: Float(rs.tone),
                        ta: rs.ta ? 1.0 : 0.0,
                        fret: Float(self.fret)
                    )
                    guard let latentInput = maybeLatent, let instrumentIndex = maybeInstrID else {
                        print("❌ Failed to build Prism input")
                        continue
                    }
                    // PrismDecoder requires a rank‑1 Float32 vector for instrument_input
                    let instrArray = try! MLMultiArray(shape: [1], dataType: .float32)
                    instrArray[0] = NSNumber(value: Float(instrumentIndex))
                    let provider = try! MLDictionaryFeatureProvider(dictionary: [
                        "latent_input": MLFeatureValue(multiArray: latentInput),
                        "instrument_input": MLFeatureValue(multiArray: instrArray)
                    ])
                    // 4) Decode via PrismDecoder
                    guard let decoder = self.prismDecoder else {
                        print("⚠️ PrismDecoder not loaded")
                        continue
                    }
                    let output: MLFeatureProvider
                    do {
                        output = try decoder.prediction(from: provider)
                    } catch {
                        print("❌ PrismDecoder prediction failed: \(error)")
                        continue
                    }
                    // Bind rawAudioArray for debug and conversion
                    guard let rawAudioArray = output.featureValue(for: "Identity")?.multiArrayValue else {
                        print("❌ PCM conversion failed")
                        continue
                    }
                    // DEBUG: inspect raw model output before conversion
                    let sampleCount = rawAudioArray.count
                    let previewCount = min(10, sampleCount)
                    let rawSamples = (0..<previewCount).map { rawAudioArray[$0].floatValue }
                    print("🐙 Model raw output samples:", rawSamples, "total count:", sampleCount)
                    guard let monoPCM = Self.convertToPCMBuffer(from: rawAudioArray) else {
                        print("❌ PCM conversion failed")
                        continue
                    }
                    if let stereoPCM = Self.convertMonoToStereo(monoPCM, pan: panPositions[trackIndex]) {
                        // Volume scaling: emphasize red and yellow, others in background
                        let colorLower = colorName.lowercased()
                        let gain: Float = (colorLower == "red" || colorLower == "yellow") ? 1.0 : 0.3
                        let channelCount = Int(stereoPCM.format.channelCount)
                        let frameLength = Int(stereoPCM.frameLength)
                        for ch in 0..<channelCount {
                            let data = stereoPCM.floatChannelData![ch]
                            for i in 0..<frameLength {
                                data[i] *= gain
                            }
                        }
                        // Log first few samples of the stereo buffer (left channel)
                        let channelData = stereoPCM.floatChannelData![0]
                        let sampleCount = Int(stereoPCM.frameLength)
                        let previewCount = min(10, sampleCount)
                        let previewSamples = (0..<previewCount).map { channelData[$0] }
                        print("▶️ Output waveform samples:", previewSamples)
                        // Compute and log full-buffer statistics
                        let totalSamples = Int(stereoPCM.frameLength)
                        var minAmp: Float = channelData[0]
                        var maxAmp: Float = channelData[0]
                        var sumSquares: Float = 0
                        for i in 0..<totalSamples {
                            let v = channelData[i]
                            minAmp = min(minAmp, v)
                            maxAmp = max(maxAmp, v)
                            sumSquares += v * v
                        }
                        let rms = sqrt(sumSquares / Float(totalSamples))
                        print("▶️ Waveform stats - min: \(minAmp), max: \(maxAmp), rms: \(rms)")
                        buffers.append(stereoPCM)
                    } else {
                        print("❌ Stereo conversion failed")
                    }
                }
                // Skip this column if no buffers were collected
                if buffers.isEmpty { continue }
                // Use a rock pentatonic interval pattern for semitones
                let semitonePattern: [Float] = (0..<buffers.count).map { trackIndex in
                    // Rock pentatonic intervals: root, minor third, fourth, fifth, minor seventh, octave
                    let rockIntervals: [Float] = [0, 3, 5, 7, 10, 12]
                    return rockIntervals[trackIndex % rockIntervals.count]
                }
                // Space out column playback for rhythmic feel
                let columnDelay = 0.0  // play immediately
                DispatchQueue.main.asyncAfter(deadline: .now() + columnDelay) {
                    self.playBuffersWithPitch(buffers, semitonePattern: semitonePattern)
                }
            }
        }
        DispatchQueue.global(qos: .userInitiated).async(execute: work)
    }



    func selectInstrumentStr(basePrefix: String, tone: Float, fret: Int, columnCount: Int, totalYellowInColumn: Int) -> String? {
        // Select only from valid suffixes for the given prefix.
        guard let suffixes = InstrumentDB.suffixesByPrefix[basePrefix], !suffixes.isEmpty else {
            print("❌ No suffixes found for basePrefix: \(basePrefix)")
            return nil
        }
        // Compute an index based on tone, fret, columnCount, and totalYellowInColumn, but clamp to valid suffixes.
        // For example, use a weighted sum as before, but ensure index is within bounds.
        let rawIndex = Int(tone * 100) + min(10, fret) + min(10, totalYellowInColumn - 1)
        let idx = max(0, min(rawIndex, suffixes.count - 1))
        let suffix = suffixes[idx]
        let instrumentStr = "\(basePrefix)_\(suffix)"
        // Guard clause to ensure validity
        guard InstrumentDB.instrumentStrs.contains(instrumentStr) else {
            print("❌ Invalid instrumentStr generated: \(instrumentStr)")
            return nil
        }
        print("🎸 instrumentStr selected: \(instrumentStr)")
        return instrumentStr
    }

    /// STEP2: アナログ値やスイッチを含めた連続ベクトルを生成
    func buildPrismInput(
        color: CubeColor, octave: Int, countInColumn: Int,
        pickupOn: Bool, phaseOn: Bool,
        volume: Float, tone: Float, ta: Float, fret: Float
    ) -> (latent: MLMultiArray?, instrID: Int?) {
        // 1) 色→候補プリフィックス対応表（複数可）
        // Deterministically select basePrefix by color
        let basePrefix: String
        switch color {
        case .red:
            basePrefix = "vocal_acoustic"
        case .yellow:
            basePrefix = "guitar_electronic"
        case .blue:
            basePrefix = "bass_electronic"
        case .green:
            basePrefix = "mallet_acoustic"
        case .orange:
            basePrefix = "keyboard_electronic"
        case .white:
            basePrefix = "organ_acoustic"
        }

        guard let instrumentStr = selectInstrumentStr(
            basePrefix: basePrefix,
            tone: tone,
            fret: Int(fret),
            columnCount: countInColumn,
            totalYellowInColumn: 1
        ) else {
            // selectInstrumentStr がエラーを出力済み
            return (nil, nil)
        }
        let instStr = instrumentStr
        // PrismDecoder expects the **global index** of the instrument within the flat
        // InstrumentDB.instrumentStrs array, **not** the numeric suffix.
        guard let instrumentIndex = InstrumentDB.instrumentStrs.firstIndex(of: instStr) else {
            print("❌ instrumentStr not found in master list: \(instStr)")
            return (nil, nil)
        }
        // 2) qualities one-hot
        let qualOneHot = [Float](repeating: 0, count: InstrumentDB.qualities.count)
        // Calculate indices and normalized values up front
        let srcIdx = instrumentSourceIndex(instStr)
        let famIdx = instrumentFamilyIndex(instStr)
        let normPitch    = (Float(octave * 12) / 127.0) * 2 - 1
        let normVelocity = (volume / 127.0) * 2 - 1
        // Use central encoder to build latent and instrument arrays
        do {
            let metadata = AudioMetadata(
                pitch: normPitch, velocity: normVelocity,
                instrument: instrumentIndex,
                instrumentFamily: famIdx,
                instrumentSource: srcIdx,
                qualities: qualOneHot.map { Float($0) }
            )
            let latentArray = try PrismInputEncoder.latentInput(from: metadata)
            // instrumentIndex is already correct; return for instrument_input
            return (latentArray, instrumentIndex)
        } catch {
            print("❌ Prism input encoding error: \(error)")
            return (nil, instrumentIndex)
        }
    }

      
// MARK: - Audio Playback Helper
    /// Plays a given AVAudioPCMBuffer using the shared AVAudioEngine and AVAudioPlayerNode.
    /// - Parameter buffer: The AVAudioPCMBuffer to play.
    func playSound(buffer: AVAudioPCMBuffer) {
        let (engine, player) = Self.sharedAudio
        if !engine.isRunning {
            do {
                try engine.start()
            } catch {
                print("⚠️ AVAudioEngine failed to start in playSound: \(error)")
            }
        }
        player.stop()
        engine.disconnectNodeOutput(player)
        engine.connect(player, to: engine.mainMixerNode, format: buffer.format)
        player.scheduleBuffer(buffer, at: nil, options: .interrupts)
        player.volume = 1.0
        player.play()
        print("▶️ playSound: AVAudioPlayerNode.play() called")
    }
    
    
    /// 26次元ベクトルからRedSpecial.sharedへパラメータ適用
    func applyAIAdjustment(from vector: [Float]) {
        guard vector.count >= 26 else {
            print("❌ 入力ベクトルが26次元未満")
            return
        }
        RedSpecial.initializeIfNeeded()
        guard let redVM = RedSpecial.shared else { return }

        // スイッチ設定（仮: 0〜1をboolと解釈）
        redVM.ps1 = vector[0] > 0.5
        redVM.ps2 = vector[1] > 0.5
        redVM.ps3 = vector[2] > 0.5
        redVM.phs1 = vector[3] > 0.5
        redVM.phs2 = vector[4] > 0.5
        redVM.phs3 = vector[5] > 0.5
        redVM.ta = vector[6] > 0.5

        // 音色と音量
        redVM.tone = Double(vector[7] * 100).clamped(to: 0...100)
        redVM.volume = Double(vector[8]).clamped(to: 0...1)

        // フレット（1〜22）
        let fret = Int(vector[9] * 21) + 1
        redVM.fret = fret.clamped(to: 1...22)

        // フレット幅（仮に10段階）
        redVM.fretWidth = Int(vector[10] * 10).clamped(to: 1...10)

        // トレモロアーム角度（-30〜30度）
        redVM.tremoloAngle = Double(vector[11] * 60 - 30)

        // カラー群のシーン記述を反映（仮：色分布の重心方向）
        redVM.directionHint = SIMD2<Double>(Double(vector[12] - 0.5) * 2,
                                            Double(vector[13] - 0.5) * 2)

        // プレイヤーモード切り替え（Red = Freddie, Yellow = Brian）
        let redLevel = vector[14]
        let yellowLevel = vector[15]
        redVM.dominantPlayer = (redLevel > yellowLevel) ? "freddie" : "brian"

        // 必要ならその他のベクトル成分も拡張可能
    }

    /// [[[Color]]] から特徴量抽出→AIパラメータベクトルへ
    func analyzeColorGroup(from colorMatrix: [[[Color]]]) -> [Float] {
        // 例：Redの直線性、Yellowの散布度などの特徴を抽出
        var featureVector: [Float] = Array(repeating: 0.0, count: 26)
        // 仮実装：RedとYellowの出現頻度
        var redCount = 0
        var yellowCount = 0
        for plane in colorMatrix {
            for row in plane {
                for color in row {
                    let name = RedSpecial.colorName(from: color)
                    if name == "red" {
                        redCount += 1
                    } else if name == "yellow" {
                        yellowCount += 1
                    }
                }
            }
        }
        let total = max(1, redCount + yellowCount)
        featureVector[14] = Float(redCount) / Float(total)
        featureVector[15] = Float(yellowCount) / Float(total)
        // 他の情報も必要に応じて featureVector[16...] に埋める
        return featureVector
    }

    /// カラー群からAI調整→WAVファイル名生成（仮）
    func generateCoreMLWavFileName(from colorMatrix: [[[Color]]]) -> String {
        let vector = analyzeColorGroup(from: colorMatrix)
        applyAIAdjustment(from: vector)
        return "generated_from_coreml.wav"
    }
}

    /// Undo履歴に基づき、SCATシンボルとRedSpecial状態を連動して再生する
    func performUndoPlayback(undoStates: [RedSpecialState]) {
        // 1. RedSpecial.sharedが存在することを確認
        guard let redSpecial = RedSpecial.shared else {
            print("❌ RedSpecial.sharedが存在しません")
            return
        }

        for state in undoStates {
            // 2. RedSpecial状態を適用（スイッチ、トレモロアーム、フレット、ボリューム等を更新）
            redSpecial.apply(state)

            // 3. SCATシンボルがあればSCATVoiceで再生
            if !state.scatSymbol.isEmpty {
                SCATVoice.shared.play(symbol: state.scatSymbol)
            }

            // 4. AI演出調整などが必要であればここで呼ぶ
            // 例: AIController.shared.adjustVisuals(for: state)

            // 5. セルを1つずつ再生するためのディレイ
            Thread.sleep(forTimeInterval: 0.2)
        }
    }


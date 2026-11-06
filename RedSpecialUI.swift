import SwiftUI
import AVFoundation
// import SwiftUI
import CoreML
import UIKit
import UniformTypeIdentifiers
import MusicKit
import simd
import CoreGraphics


func debugLog(_ message: String) {
    print(message)
}


enum RedSpecial {
    // Use Option type for shared singleton
    static var shared: SwitchViewModel? = nil

    static func initializeIfNeeded() {
        if RedSpecial.shared == nil {
            let cubeVM = CubicModel()
            let mappingModel = MappingModel(cubicModel: cubeVM)
            RedSpecial.shared = SwitchViewModel(cubeVM: cubeVM, mappingModel: mappingModel)
            print("✅ RedSpecial.shared 初期化済み（RedSpecial.initializeIfNeeded）")
        }
    }

    static func colorName(from color: Color) -> String {
        // Replace with actual logic if needed
        let uiColor = UIColor(color)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        uiColor.getRed(&red, green: &green, blue: &blue, alpha: nil)
        switch (red, green, blue) {
        case (1.0, 0.0, 0.0): return "red"
        case (0.0, 1.0, 0.0): return "green"
        case (0.0, 0.0, 1.0): return "blue"
        case (1.0, 1.0, 0.0): return "yellow"
        case (1.0, 0.5, 0.0): return "orange"
        case (1.0, 1.0, 1.0): return "white"
        case (0.5, 0.5, 0.5): return "gray"
        default: return "unknown"
        }
    }

    /// CoreML WAVファイル名生成（仮実装: ファイル名を返すだけ）
    func generateCoreMLWavFileName(from colorMatrix: [[[Color]]]) -> String {
        // CoreML生成ロジックをここに実装（仮でファイル名を返す）
        return "generated_from_coreml.wav"
    }
}


// MARK: - RedSpecialSwitchState
struct RedSpecialSwitchState {
    var ps1: Bool
    var ps2: Bool
    var ps3: Bool
    var phs1: Bool
    var phs2: Bool
    var phs3: Bool
    var ta: Bool
    var tone: Double
    var volume: Double
    var pickupPosition: String
}



// MARK: - TAView
struct TAView: View {
    @Binding var tone: Double

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                RoundedRectangle(cornerRadius: 4)
                    .strokeBorder(Color.white, lineWidth: 1)
                    .background(Color.gray.opacity(0.3))
                    .overlay(
                        Text("TA")
                            .font(.caption)
                            .foregroundColor(.yellow)
                    )
                TAHorizontalSlider(value: $tone, range: 0.0...100.0, step: 1.0)
                    .frame(width: proxy.size.width * 0.8, height: proxy.size.height * 0.4)
                    .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
                    .background(Color.clear)
            }
        }
    }
}

// MARK: - TAHorizontalSlider
struct TAHorizontalSlider: UIViewRepresentable {
    typealias UIViewType = CustomSlider
    @Binding var value: Double
    var range: ClosedRange<Double>
    var step: Double

    func makeUIView(context: Context) -> CustomSlider {
        let width: CGFloat = 80
        let height: CGFloat = 240
        let slider = CustomSlider(frame: CGRect(x: 0, y: 0, width: width, height: height))
        slider.minimumValue = Float(range.lowerBound)
        slider.maximumValue = Float(range.upperBound)
        slider.value = Float(value)
        slider.addTarget(context.coordinator, action: #selector(Coordinator.valueChanged(_:)), for: .valueChanged)
        
        let thumbWidth: CGFloat = 20
        let thumbHeight: CGFloat = height * 0.9
        let thumbSize = CGSize(width: thumbWidth, height: thumbHeight)
        UIGraphicsBeginImageContextWithOptions(thumbSize, false, 0.0)
        let ctx = UIGraphicsGetCurrentContext()!
        let gradientColors = [UIColor.white.cgColor, UIColor.lightGray.cgColor]
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let gradient = CGGradient(colorsSpace: colorSpace, colors: gradientColors as CFArray, locations: [0.0, 1.0])!
        let startPoint = CGPoint(x: thumbWidth / 2, y: 0)
        let endPoint = CGPoint(x: thumbWidth / 2, y: thumbHeight)
        ctx.drawLinearGradient(gradient, start: startPoint, end: endPoint, options: [])
        let ovalRect = CGRect(x: 0, y: 0, width: thumbWidth, height: thumbHeight)
        ctx.setFillColor(UIColor.white.cgColor)
        ctx.fillEllipse(in: ovalRect)
        let thumbImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        slider.setThumbImage(thumbImage, for: .normal)
        
        slider.setMinimumTrackImage(UIImage(), for: .normal)
        slider.setMaximumTrackImage(UIImage(), for: .normal)
        return slider
    }
    
    func updateUIView(_ uiView: CustomSlider, context: Context) {
        uiView.value = Float(value)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(value: $value, step: step)
    }
    
    class Coordinator: NSObject {
        var value: Binding<Double>
        var step: Double
        init(value: Binding<Double>, step: Double) {
            self.value = value
            self.step = step
        }
        @objc func valueChanged(_ sender: UISlider) {
            let newValue = Double(sender.value)
            let stepped = (newValue / step).rounded() * step
            sender.value = Float(stepped)
            value.wrappedValue = stepped
            // print("🔄 TAHorizontalSlider updated: \(stepped)")
        }
    }
}

// MARK: - CustomSlider
class CustomSlider: UISlider {
    let hitTestPadding: CGFloat = 20
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let thumbRect = self.thumbRect(forBounds: self.bounds,
                                       trackRect: self.trackRect(forBounds: self.bounds),
                                       value: self.value)
        let extendedRect = thumbRect.insetBy(dx: -hitTestPadding, dy: -hitTestPadding)
        return extendedRect.contains(point) ? self : super.hitTest(point, with: event)
    }
}


// MARK: - TASlider
struct TASlider: UIViewRepresentable {
    typealias UIViewType = CustomSlider
    @Binding var value: Double
    var range: ClosedRange<Double>
    var step: Double
    
    func makeUIView(context: Context) -> CustomSlider {
        let w: CGFloat = 40
        let h: CGFloat = 200
        let slider = CustomSlider(frame: CGRect(x: 0, y: 0, width: w, height: h))
        slider.minimumValue = Float(range.lowerBound)
        slider.maximumValue = Float(range.upperBound)
        slider.value = Float(value)
        slider.addTarget(context.coordinator, action: #selector(Coordinator.valueChanged(_:)), for: .valueChanged)
        let thumbSize = CGSize(width: w, height: h)
        UIGraphicsBeginImageContextWithOptions(thumbSize, false, 0.0)
        UIColor.white.setFill()
        UIRectFill(CGRect(origin: .zero, size: thumbSize))
        let thumbImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        slider.setThumbImage(thumbImage, for: .normal)
        slider.setMinimumTrackImage(UIImage(), for: .normal)
        slider.setMaximumTrackImage(UIImage(), for: .normal)
        //slider.transform = CGAffineTransform(rotationAngle: -CGFloat.pi / 2)
        return slider
    }
    
    func updateUIView(_ uiView: CustomSlider, context: Context) {
        uiView.value = Float(value)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(value: $value, step: step)
    }
    
    class Coordinator: NSObject {
        var value: Binding<Double>
        var step: Double
        init(value: Binding<Double>, step: Double) {
            self.value = value
            self.step = step
        }
        @objc func valueChanged(_ sender: UISlider) {
            let newVal = Double(sender.value)
            let stepped = (newVal / step).rounded() * step
            sender.value = Float(stepped)
            value.wrappedValue = stepped
            // print("🔄 VerticalSlider updated: \(stepped)")
            // soundVM.volumeValue = newVal.rounded()
            // soundVM.updateVolumeValue()
        }
    }
}

// MARK: - HorizontalSlider
struct HorizontalSlider: UIViewRepresentable {
    typealias UIViewType = CustomSlider
    @Binding var value: Double
    var range: ClosedRange<Double>
    var step: Double
    var thumbSize: CGSize = CGSize(width: 20, height: 20)

    func makeUIView(context: Context) -> CustomSlider {
        let width: CGFloat = 300
        let height: CGFloat = 40
        let slider = CustomSlider(frame: CGRect(x: 0, y: 0, width: width, height: height))
        slider.minimumValue = Float(range.lowerBound)
        slider.maximumValue = Float(range.upperBound)
        slider.value = Float(value)
        slider.addTarget(context.coordinator, action: #selector(Coordinator.valueChanged(_:)), for: .valueChanged)
        UIGraphicsBeginImageContextWithOptions(thumbSize, false, 0.0)
        let ctx = UIGraphicsGetCurrentContext()!
        ctx.setFillColor(UIColor.systemBlue.cgColor)
        ctx.fillEllipse(in: CGRect(origin: .zero, size: thumbSize))
        let thumbImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        slider.setThumbImage(thumbImage, for: .normal)
        slider.setMinimumTrackImage(UIImage(), for: .normal)
        slider.setMaximumTrackImage(UIImage(), for: .normal)
        return slider
    }
    
    func updateUIView(_ uiView: CustomSlider, context: Context) {
        uiView.value = Float(value)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(value: $value, step: step)
    }
    
    class Coordinator: NSObject {
        var value: Binding<Double>
        var step: Double
        init(value: Binding<Double>, step: Double) {
            self.value = value
            self.step = step
        }
        @objc func valueChanged(_ sender: UISlider) {
            let newValue = Double(sender.value)
            let stepped = (newValue / step).rounded() * step
            sender.value = Float(stepped)
            value.wrappedValue = stepped
            // print("🔄 HorizontalSlider updated: \(stepped)")
        }
    }
}








// MARK: - UI Views

struct SelectFolderView: View {
    @ObservedObject var musicManager = MusicManager.shared
    @State private var animate = false
    var body: some View {
        VStack {
            if let folderURL = musicManager.selectedFolderURL, musicManager.hasPlayableFiles {
                Text("Folder: \(folderURL.lastPathComponent)")
                    .font(.system(size: 12))
                    .foregroundColor(.yellow)
            } else {
                Text("Not Select")
                    .font(.headline)
                    .foregroundColor(.red)
                    .opacity(animate ? 0.2 : 1.0)
                    .onAppear {
                        withAnimation(Animation.linear(duration: 0.8).repeatForever(autoreverses: true)) {
                            animate = true
                        }
                    }
            }
        }
    }
}

struct PlayPauseView: View {
    @ObservedObject var musicManager = MusicManager.shared
    var body: some View {
        let enabled = musicManager.hasPlayableFiles
        ZStack {
            RoundedRectangle(cornerRadius: 4)
                .strokeBorder(enabled ? Color.white : Color.gray, lineWidth: 1)
                .background(enabled ? Color.gray.opacity(0.3) : Color.black.opacity(0.5))
            Button(action: {
                if enabled {
                    musicManager.handleButtonAction(for: "PlayPause")
                } else {
                    print("再生できる音源がありません")
                }
            }) {
                Text("Play/Pause")
                    .font(.caption)
                    .foregroundColor(enabled ? .yellow : .red)
            }
            .disabled(!enabled)
        }
    }
}

struct VolumeControlView: View {
    @ObservedObject var musicManager = MusicManager.shared
    var body: some View {
        VStack(spacing: 4) {
            Text("Volume: \(Double(musicManager.volume), specifier: "%.2f")")
                .font(.caption2)
                .foregroundColor(.green)
            Slider(
                value: Binding(
                    get: { Double(musicManager.volume) },
                    set: { newValue in
                        musicManager.volume = Float(newValue)
                        musicManager.player?.volume = musicManager.volume
                    }
                ),
                in: 0...1
            )
            .padding(.horizontal, 4)
        }
        .padding(2)
        .background(Color.gray.opacity(0.3))
        .cornerRadius(4)
        .scaleEffect(0.8)
    }
}

struct RepeatView: View {
    @ObservedObject var musicManager = MusicManager.shared
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 4)
                .strokeBorder(musicManager.isRepeatEnabled ? Color.yellow : Color.gray, lineWidth: 1)
                .background(
                    (musicManager.isRepeatEnabled ? Color.gray.opacity(0.3) : Color.black.opacity(0.5))
                        .cornerRadius(4)
                )
            Text("Repeat")
                .font(.caption)
                .foregroundColor(musicManager.isRepeatEnabled ? .yellow : .gray)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onTapGesture {
            //RedSpecial.shared?.handleInteraction(id: "Repeat", size: nil, offset: nil)
        }
    }
}

struct ShuffleView: View {
    @ObservedObject var musicManager = MusicManager.shared
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 4)
                .strokeBorder(musicManager.isShuffleEnabled ? Color.yellow : Color.gray, lineWidth: 1)
                .background(
                    (musicManager.isShuffleEnabled ? Color.gray.opacity(0.3) : Color.black.opacity(0.5))
                        .cornerRadius(4)
                )
            Text("Shuffle")
                .font(.caption)
                .foregroundColor(musicManager.isShuffleEnabled ? .yellow : .gray)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onTapGesture {
            //RedSpecial.shared?.handleInteraction(id: "Shuffle", size: nil, offset: nil)
        }
    }
}




// MARK: - AudioEngineManager
class AudioEngineManager {
    static let shared = AudioEngineManager()
    let engine = AVAudioEngine()
    public let playerNode = AVAudioPlayerNode()
    public var eq = AVAudioUnitEQ(numberOfBands: 1)

    init() {
        setupAudioSession()
        // Attach and connect playerNode at initialization
        engine.attach(playerNode)
        engine.connect(playerNode, to: engine.mainMixerNode, format: nil)
        do {
            try engine.start()
        } catch {
            print("Audio engine failed to start: \(error)")
        }
        setupAudioEngine()
    }

    private func setupAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.ambient, mode: .default, options: [])
            try session.setActive(true)
            print("✅ AudioSession set to ambient")
        } catch {
            print("❌ AudioSession error: \(error.localizedDescription)")
        }
    }

    private func setupAudioEngine() {
        let mainMixer = engine.mainMixerNode
        engine.attach(eq)
        engine.connect(eq, to: mainMixer, format: nil)
        do {
            try engine.start()
            print("✅ AudioEngine started")
        } catch {
            print("❌ AudioEngine start error: \(error.localizedDescription)")
        }
    }

    func convertBuffer(_ buffer: AVAudioPCMBuffer, to format: AVAudioFormat) -> AVAudioPCMBuffer? {
        guard let converter = AVAudioConverter(from: buffer.format, to: format) else {
            print("❌ Converter creation error")
            return nil
        }
        guard let newBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: buffer.frameCapacity) else {
            return nil
        }
        var error: NSError?
        let inputBlock: AVAudioConverterInputBlock = { _, outStatus in
            outStatus.pointee = .haveData
            return buffer
        }
        converter.convert(to: newBuffer, error: &error, withInputFrom: inputBlock)
        if let error = error {
            print("❌ Converter error: \(error.localizedDescription)")
            return nil
        }
        return newBuffer
    }

    func playSound(fileName: String, toneValueT: Double = 5.0) {
        RedSpecial.initializeIfNeeded()
        print("🔊 Playing: \(fileName)")
        print("📝 [Audio Playback] Selected filename: \(fileName)")

        // Remove per-call engine.attach/connect/start logic.
        // Use the shared playerNode and engine, and schedule buffer.
        guard let buffer = createBuffer(from: fileName, pitch: toneValueT) else { return }
        playerNode.scheduleBuffer(buffer, at: nil, options: [], completionHandler: nil)
        if !playerNode.isPlaying {
            playerNode.play()
        }
    }

    // Helper to create buffer from file name and pitch (toneValueT)
    private func createBuffer(from fileName: String, pitch: Double) -> AVAudioPCMBuffer? {
        // Instead of searching bundle, assume CoreML-generated WAV is in temp directory or a known location.
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL: URL
        if fileName.hasSuffix(".wav") {
            fileURL = tempDir.appendingPathComponent(fileName)
        } else {
            // For bundled files (e.g., m4a), fallback to bundle (legacy, if needed)
            if let bundleURL = Bundle.main.url(forResource: fileName, withExtension: nil) {
                fileURL = bundleURL
            } else {
                print("Audio file '\(fileName)' not found in bundle or temp directory")
                return nil
            }
        }
        var audioFile: AVAudioFile? = nil
        do {
            audioFile = try AVAudioFile(forReading: fileURL, commonFormat: .pcmFormatFloat32, interleaved: false)
        } catch {
            print("❌ Audio playback error: \(error.localizedDescription) for file \(fileName)")
            return nil
        }
        guard let audioFile = audioFile else {
            print("❌ Could not load audio file for \(fileName)")
            return nil
        }
        guard var buffer = AVAudioPCMBuffer(pcmFormat: audioFile.processingFormat,
                                            frameCapacity: AVAudioFrameCount(audioFile.length)) else {
            print("❌ Buffer creation error")
            return nil
        }
        do {
            try audioFile.read(into: buffer)
        } catch {
            print("❌ Error reading audio file into buffer: \(error.localizedDescription)")
            return nil
        }
        // Mono to Stereo Conversion
        if buffer.format.channelCount == 1 {
            let stereoFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32,
                                             sampleRate: buffer.format.sampleRate,
                                             channels: 2,
                                             interleaved: false)!
            if let converter = AVAudioConverter(from: buffer.format, to: stereoFormat),
               let convertedBuffer = AVAudioPCMBuffer(pcmFormat: stereoFormat,
                                                      frameCapacity: buffer.frameCapacity) {
                var error: NSError?
                converter.convert(to: convertedBuffer, error: &error) { _, outStatus in
                    outStatus.pointee = .haveData
                    return buffer
                }
                if let error = error {
                    print("⚠️ Audio format conversion failed: \(error)")
                } else {
                    buffer = convertedBuffer
                }
            }
        }
        let mainMixer = engine.mainMixerNode
        let outputFormat = mainMixer.outputFormat(forBus: 0)
        var finalBuffer = buffer
        if buffer.format.channelCount != outputFormat.channelCount {
            print("⚠️ Format conversion start: buffer.channels=\(buffer.format.channelCount), output.channels=\(outputFormat.channelCount)")
            if let convertedBuffer = self.convertBuffer(buffer, to: outputFormat) {
                finalBuffer = convertedBuffer
                print("✅ Format conversion complete")
            } else {
                print("❌ Buffer conversion failed")
                return nil
            }
        }
        // Optionally apply toneValueT filtering, not implemented here
        return finalBuffer
    }

    /// Play a single snapshot note by MIDI pitch and velocity.
    func playSnapshot(pitch: Int, velocity: Int) {
        print("🔊 playSnapshot called with pitch: \(pitch), velocity: \(velocity)")
        // Load SoundFont and only create sampler if successful
        guard let sf2url = Bundle.main.url(forResource: "GeneralUser GS", withExtension: "sf2") else {
            print("❌ SoundFontファイルが見つかりません")
            return
        }
        let sampler = AVAudioUnitSampler()
        do {
            try sampler.loadInstrument(at: sf2url)
        } catch {
            print("❌ SoundFontロード失敗: \(error)")
            return
        }
        // Attach and connect sampler after successful load
        engine.attach(sampler)
        engine.connect(sampler, to: eq, format: nil)
        // Play note
        sampler.startNote(UInt8(pitch), withVelocity: UInt8(velocity), onChannel: 0)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            sampler.stopNote(UInt8(pitch), onChannel: 0)
            self.engine.detach(sampler)
        }
    }

    /// Play a WAV file from a given URL using the shared playerNode and engine.
    func playSoundFromURL(_ fileURL: URL) {
        do {
            let audioFile = try AVAudioFile(forReading: fileURL)
            let format = audioFile.processingFormat
            guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(audioFile.length)) else {
                print("❌ Buffer creation failed")
                return
            }
            try audioFile.read(into: buffer)
            playerNode.scheduleBuffer(buffer, at: nil, options: [], completionHandler: nil)
            if !playerNode.isPlaying {
                playerNode.play()
            }
        } catch {
            print("❌ Failed to play WAV from URL: \(error.localizedDescription)")
        }
    }
}


struct FretScopeView: View {
    @ObservedObject var redVM: SwitchViewModel
    @Binding var selectedFretIndex: Int {
        didSet {
            redVM.fret = selectedFretIndex
        }
    }
    @State private var scatFretCenter: Double = 11.5
    @Binding var selectedScatSymbol: String?

    private var viewBody: some View {
        VStack(spacing: 8) {
            fretAndScatScopeView
        }
        .padding(4)
        .background(Color.gray.opacity(0.3))
        .cornerRadius(6)
        .scaleEffect(0.8)
        .onChange(of: redVM.fret) {
            if selectedFretIndex != redVM.fret {
                selectedFretIndex = redVM.fret
            }
        }
    }

    private var fretAndScatScopeView: some View {
        HStack(spacing: 4) {
            blueFretScopeView
            scatColumnView
        }
    }

    private var blueFretScopeView: some View {
        VStack(spacing: 4) {
            Text("Fret: \(redVM.fret) ± \(redVM.fretWidth / 2)")
                .font(.caption2)
                .foregroundColor(.orange)
            FretScopeNoteView(
                fretCenter: $redVM.fretDouble,
                selectedFretIndex: $selectedFretIndex,
                selectedScatSymbol: .constant(nil),
                isScatMode: false
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Color.blue.opacity(0.3))
        .cornerRadius(4)
    }

    var body: some View { viewBody }

    private var scatColumnView: some View {
        VStack(spacing: 4) {
            Text("SCAT")
                .font(.caption2)
                .foregroundColor(.red)
            FretScopeNoteView(
                fretCenter: $scatFretCenter,
                selectedFretIndex: .constant(0),
                selectedScatSymbol: $selectedScatSymbol,
                visibleRange: 10,
                isScatMode: true
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Color.red.opacity(0.3))
        .cornerRadius(4)
    }
}

// (Removed duplicate/empty class RedSpecial: ObservableObject)

struct RedSpecial_Previews: PreviewProvider {
    static var previews: some View {
        let cubeVM = CubicModel()
        let mappingModel = MappingModel(cubicModel: cubeVM)
        let switchVM = SwitchViewModel(cubeVM: cubeVM, mappingModel: mappingModel)
        RedSpecial.shared = switchVM
        return ContentView()
    }
}





// MARK: - FretScopeNoteView
struct FretScopeNoteView: View {
    @Binding var fretCenter: Double
    @Binding var selectedFretIndex: Int
    @Binding var selectedScatSymbol: String?
    let fretMin: Int = 1
    let fretMax: Int = 22
    var visibleRange: Int = 6

    let keyRoot: Int = 57  // MIDI A3
    let scaleNotes: [Int] = [0, 2, 4, 5, 7, 9, 11] // Major scale

    @GestureState private var dragOffset: CGFloat = 0
    @State private var baseOffset: CGFloat = 0

    // New parameter: isScatMode (default false)
    var isScatMode: Bool = false

    private var viewBody: some View {
        GeometryReader { geo in
            let (frets, rowHeight) = visibleFrets(for: geo.size.height)
            VStack(spacing: 0) {
                if isScatMode {
                    ForEach(Array(frets.enumerated()), id: \.1) { index, fret in
                        scatRow(fret: fret, index: index, rowHeight: rowHeight)
                    }
                } else {
                    ForEach(frets, id: \.self) { fret in
                        let midi = keyRoot + fret
                        let semitoneRaw = midi % 12
                        let noteName = noteNameFor(semitoneRaw)
                        let inScale = scaleNotes.contains(semitoneRaw)
                        ZStack {
                            Rectangle()
                                .fill(inScale ? Color.blue.opacity(0.7) : Color.gray.opacity(0.3))
                            VStack {
                                Text("F\(fret)")
                                    .font(.caption2)
                                    .foregroundColor(.white)
                                Text(noteName)
                                    .font(.title3)
                                    .foregroundColor(.white)
                            }
                        }
                        .frame(height: rowHeight)
                        // --- Replace .onTapGesture for cell selection/SCAT assignment ---
                        .onTapGesture {
                            print("🐞 Tapped cell.id = \(fret), selectedScatSymbol = \(selectedScatSymbol ?? "-")")
                            // Only allow selection for left, front, right faces (simulate facelet.face check)
                            // In actual ContentView, check: [.left, .front, .right].contains(cell.facelet.face)
                            // Here, we'll assume all frets are eligible for demonstration.
                            // You may want to add a condition if you have face info here.
                            // For now, mimic the logic.
                            // let cell = ... (not available here)
                            // guard [.left, .front, .right].contains(cell.facelet.face) else { return }
                            // Instead, always allow:
                            if let selectedCellIDs = Mirror(reflecting: selectedFretIndex).descendant("selectedCellIDs") as? Set<String> {
                                var mutableCellIDs = selectedCellIDs
                                let cellID = String(fret)
                                if mutableCellIDs.contains(cellID) {
                                    mutableCellIDs.remove(cellID)
                                } else {
                                    mutableCellIDs.insert(cellID)
                                }
                                // Not possible to update parent state here; this is for illustration.
                            }
                        }
                    }
                }
            }
            .gesture(
                DragGesture(minimumDistance: 1)
                    .updating($dragOffset) { value, state, _ in
                        state = value.translation.height
                    }
                    .onEnded { value in
                        let (_, rowHeight) = visibleFrets(for: geo.size.height)
                        let centerFret = Int(round(fretCenter))
                        let delta = value.translation.height / rowHeight
                        let step = -Int(round(delta))
                        let newFret = (centerFret + step).clamped(to: fretMin...fretMax)
                        fretCenter = Double(newFret)
                        selectedFretIndex = newFret
                    }
            )
        }
    }

    var body: some View { viewBody }

    private func visibleFrets(for geoHeight: CGFloat) -> ([Int], CGFloat) {
        let rowHeight = geoHeight / CGFloat(visibleRange)
        let centerFret = Int(round(fretCenter))
        let halfVisible = visibleRange / 2
        let lowerBound = max(fretMin, centerFret - halfVisible)
        let upperBound = min(fretMax, lowerBound + visibleRange - 1)
        let visibleRange = lowerBound...upperBound
        return (Array(visibleRange), rowHeight)
    }

    @ViewBuilder
    private func scatRow(fret: Int, index: Int, rowHeight: CGFloat) -> some View {
        let midi = keyRoot + fret
        let semitoneRaw = midi % 12
        let noteName = noteNameFor(semitoneRaw)
        
        ZStack {
            Rectangle()
                .fill(index % 2 == 0 ? Color.red.opacity(0.7) : Color.gray.opacity(0.7))
            Text(noteName)
                .font(.caption)
                .foregroundColor(.white)
                .onTapGesture {
                    selectedScatSymbol = noteName
                    print("🎤 SCAT selected: \(noteName)")
                    // (Removed SCAT file playback and fallback synthesis logic)
                }
        }
        .frame(height: rowHeight)
    }

    func noteNameFor(_ semitone: Int) -> String {
        if isScatMode {
            let scatNames = [
                "Day-oh", "Dey", "Wey-oh", "Ay-oh", "E-oh",
                "Bah", "Bap", "Flash", "Shoo", "Doo",
                "Da", "Ba", "La", "Lala", "Wa", "Za", "Scoo"
            ]
            let index = semitone % scatNames.count
            return scatNames[index]
        } else {
            let names = ["C", "C♯", "D", "D♯", "E", "F", "F♯", "G", "G♯", "A", "A♯", "B"]
            return names[semitone % 12]
        }
    }
}
struct VerticalSlider: UIViewRepresentable {
    typealias UIViewType = CustomSlider
    @Binding var value: Double
    var range: ClosedRange<Double>
    var step: Double
    
    func makeUIView(context: Context) -> CustomSlider {
        let w: CGFloat = 190
        let h: CGFloat = 120
        let slider = CustomSlider(frame: CGRect(x: 0, y: 0, width: w, height: h))
        slider.minimumValue = Float(range.lowerBound)
        slider.maximumValue = Float(range.upperBound)
        slider.value = Float(value)
        slider.addTarget(context.coordinator, action: #selector(Coordinator.valueChanged(_:)), for: .valueChanged)
        let thumbSize = CGSize(width: w, height: h)
        UIGraphicsBeginImageContextWithOptions(thumbSize, false, 0.0)
        //UIColor.white.setFill()
        UIColor.white.withAlphaComponent(0.4).setFill()
        UIRectFill(CGRect(origin: .zero, size: thumbSize))
        let thumbImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        slider.setThumbImage(thumbImage, for: .normal)
        slider.setMinimumTrackImage(UIImage(), for: .normal)
        slider.setMaximumTrackImage(UIImage(), for: .normal)
        slider.transform = CGAffineTransform(rotationAngle: -CGFloat.pi / 2)
        return slider
    }
    
    func updateUIView(_ uiView: CustomSlider, context: Context) {
        uiView.value = Float(value)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(value: $value, step: step)
    }
    
    class Coordinator: NSObject {
        var value: Binding<Double>
        var step: Double
        init(value: Binding<Double>, step: Double) {
            self.value = value
            self.step = step
        }
        @objc func valueChanged(_ sender: UISlider) {
            let newValue = Double(sender.value)
            let stepped = (newValue / step).rounded() * step
            sender.value = Float(stepped)
            value.wrappedValue = stepped
            // print("🔄 VerticalSlider updated: \(stepped)")
        }
    }
}




struct FretScope2DSlider: View {
    @Binding var fretCenter: Double
    @Binding var fretWidth: Double

    @State private var ballTiltAngle: Angle = .zero
    @State private var verticalOffset: CGFloat = 0
    @State private var initialOffset: CGFloat = 0
    @State private var lastAngle: Double = 0

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            let gridUnitHeight = size.height / 22
            let knobHeight = gridUnitHeight
            let usableHeight = size.height - knobHeight
            let fretMin: Double = 1
            let fretMax: Double = 22
            let fretRange: Double = fretMax - fretMin
            let centerY: CGFloat = size.height / 2 + verticalOffset
 
            let ballCount = 6
            let ballDiameter = gridUnitHeight * 2.5
 
            ZStack {
                // 🟠 Orange Ball Row (Rotates as group)
                ZStack {
                    let stringNames = ["E", "A", "D", "G", "B", "e"]
                    ForEach(0..<ballCount, id: \.self) { index in
                        let offsetIndex = CGFloat(index) - CGFloat(ballCount - 1) / 2.0
                        ZStack {
                            Circle()
                                .fill(Color.orange)
                                .frame(width: ballDiameter, height: ballDiameter)
                            Text(stringNames[index])
                                .font(.caption2)
                                .foregroundColor(.black)
                        }
                        .offset(x: ballDiameter * offsetIndex)
                    }
                }
                .frame(width: ballDiameter * CGFloat(ballCount + 1), height: ballDiameter)
                .position(x: size.width / 2, y: centerY)
                .rotationEffect(ballTiltAngle)
                .gesture(
                    DragGesture(minimumDistance: 5)
                        .onChanged { value in
                            let rotationAmount = Double(value.translation.width) / 2.0
                            self.ballTiltAngle = Angle(degrees: self.lastAngle + rotationAmount)
                            print("↩️ Orange ball rotated: \(self.ballTiltAngle.degrees)°")
                        }
                        .onEnded { value in
                            let rotationAmount = Double(value.translation.width) / 2.0
                            self.lastAngle += rotationAmount
                        }
                )
 
                // 🔵 Blue Knob
                Circle()
                    .fill(Color.blue)
                    .frame(width: ballDiameter, height: ballDiameter)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 1)
                            .onChanged { value in
                                let delta = value.translation.height
                                let newOffset = (initialOffset + delta).clamped(to: -usableHeight / 2 ... usableHeight / 2)
                                
                                verticalOffset = newOffset
 
                                let fretRatio = (newOffset + usableHeight / 2) / usableHeight
                                fretCenter = (fretMin + fretRatio * fretRange).clamped(to: fretMin...fretMax)
                            }
                            .onEnded { _ in
                                initialOffset = verticalOffset
                            }
                    )
                    .position(x: size.width / 2 - (ballDiameter * CGFloat(ballCount) / 2) - ballDiameter / 2,
                              y: centerY)
            }
            .onAppear {
                let normalized = (fretCenter - fretMin) / fretRange
                verticalOffset = usableHeight * CGFloat(normalized - 0.5)
                initialOffset = verticalOffset
            }
        }
    }
}



    private func instrumentPrefix(for player: String) -> String {
        // Returns the correct prefix for each player name
        switch player {
        case "Freddie": return "keyboard_acoustic_003"
        case "John": return "bass_electric_002"
        case "Brian": return "keyboard_acoustic_003"
        case "Roger": return "drum_machine_004"
        default: return "keyboard_acoustic_003"
        }
    }





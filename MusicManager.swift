import SwiftUI
import AVFoundation
import UIKit
import UniformTypeIdentifiers
import simd
import CoreGraphics

@preconcurrency import AVFoundation  // Swift 6

// =======================================================
// MARK: - MusicManager
// =======================================================
class MusicManager: NSObject, ObservableObject, AVAudioPlayerDelegate, UIDocumentPickerDelegate {
    enum MusicManagerError: LocalizedError {
        case audioSessionSetupFailed(Error)
        case securityScopeAccessDenied(URL)
        case fileCoordinationFailed(URL, Error)
        case coordinatedReadDidNotRun(URL)
        case playerPreparationFailed(URL)
        case playerStartFailed(URL)

        var errorDescription: String? {
            switch self {
            case .audioSessionSetupFailed(let error):
                return "AVAudioSession の設定に失敗しました: \(error.localizedDescription)"
            case .securityScopeAccessDenied(let url):
                return "security-scoped resource を開始できません: \(url.lastPathComponent)"
            case .fileCoordinationFailed(let url, let error):
                return "ファイル調整に失敗しました: \(url.lastPathComponent) (\(error.localizedDescription))"
            case .coordinatedReadDidNotRun(let url):
                return "ファイル調整ブロックが実行されませんでした: \(url.lastPathComponent)"
            case .playerPreparationFailed(let url):
                return "AVAudioPlayer の準備に失敗しました: \(url.lastPathComponent)"
            case .playerStartFailed(let url):
                return "AVAudioPlayer の再生開始に失敗しました: \(url.lastPathComponent)"
            }
        }
    }

    enum MusicSourceMode {
        case offline
    }
    
    @Published var currentMode: MusicSourceMode = .offline
    @Published var isFileSelected: Bool = false
    @Published var repeatRange: ClosedRange<Int>? = nil
    
    static let shared = MusicManager()
    
    internal var player: AVAudioPlayer? {
        didSet {
            print("🎛️ AVAudioPlayer 初期化: \(player?.url?.lastPathComponent ?? "なし")")
        }
    }
    @Published var isPlaying = false
    @Published var volume: Float = 1.0
    @Published var selectedFolderURL: URL?
    @Published var isShuffleEnabled: Bool = false
    @Published var isRepeatEnabled: Bool = false
    @Published var offlinePlaylist: [URL] = []
    
    private var audioPlayer: AVAudioPlayer?
    private var shuffleHistory: [Int] = []
    private var securityScopedURLs: [URL] = []

    private var _currentOfflineIndex: Int = 0
    var currentOfflineIndex: Int {
        get { _currentOfflineIndex }
        set { _currentOfflineIndex = newValue }
    }
    
    var hasPlayableFiles: Bool {
        return !offlinePlaylist.isEmpty
    }

    var currentFileURLs: [URL] {
        return offlinePlaylist
    }
    
    var currentFolderName: String? {
        return selectedFolderURL?.lastPathComponent
    }
    
    private override init() {
        super.init()
        isRepeatEnabled = false
    }

    deinit {
        releaseSecurityScopedResources()
    }

    private func configurePlaybackSession() throws {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [])
            try session.setActive(true)
        } catch {
            throw MusicManagerError.audioSessionSetupFailed(error)
        }
    }

    private func releaseSecurityScopedResources() {
        for url in securityScopedURLs {
            url.stopAccessingSecurityScopedResource()
        }
        securityScopedURLs.removeAll()
    }

    private func withCoordinatedReadAccess<T>(to url: URL, _ body: (URL) throws -> T) throws -> T {
        let coordinator = NSFileCoordinator()
        var coordinationError: NSError?
        var result: Result<T, Error>?

        coordinator.coordinate(readingItemAt: url, options: .withoutChanges, error: &coordinationError) { coordinatedURL in
            do {
                result = .success(try body(coordinatedURL))
            } catch {
                result = .failure(error)
            }
        }

        if let coordinationError {
            throw MusicManagerError.fileCoordinationFailed(url, coordinationError)
        }
        guard let result else {
            throw MusicManagerError.coordinatedReadDidNotRun(url)
        }
        return try result.get()
    }
    
    func handleButtonAction(for id: String) {
        print("➡️ handleButtonAction: \(id)")
        switch id {
        case "PlayPause":
            togglePlayPause()
        case "Select":
            promptMusicSourceSelection()
        case "Repeat":
            toggleRepeatMode()
        case "Shuffle":
            toggleShuffleMode()
        case "Next":
            // Added red flash logic for Next button
            if currentOfflineIndex == offlinePlaylist.count - 1 && !isRepeatEnabled {
                NotificationCenter.default.post(name: Notification.Name("NextButtonFlashRed"), object: nil)
            }
            playNextTrack()
        case "Prev":
            // Added red flash logic for Prev button
            if currentOfflineIndex == 0 && !isRepeatEnabled {
                NotificationCenter.default.post(name: Notification.Name("PrevButtonFlashRed"), object: nil)
            }
            playPreviousTrack()
        default:
            print("ℹ️ 特別な処理なし")
        }
    }
    
    func togglePlayPause() {
        if let player = player {
            if player.isPlaying {
                player.pause()
                isPlaying = false
                print("⏸️ 再生停止")
            } else {
                guard player.prepareToPlay() else {
                    print("🚫 AVAudioPlayerの準備に失敗")
                    return
                }
                player.play()
                isPlaying = true
                print("▶️ 再生再開")
            }
        } else if hasPlayableFiles {
            print("▶️ 初回再生実行")
            if isShuffleEnabled && !isRepeatEnabled {
                shuffleHistory.removeAll()
                print("🧹 初回再生のため Shuffle履歴をリセット")
            }
            playOfflineCurrentFile()
        } else {
            print("🚫 再生できる音源がありません")
        }
    }
    
    func toggleRepeatMode() {
        objectWillChange.send()
        isRepeatEnabled.toggle()
        if !isRepeatEnabled && isShuffleEnabled {
            shuffleHistory.removeAll()
            print("🧹 Repeat OFF時に Shuffle履歴をリセット")
        }
        print("🔄 Repeat mode: \(isRepeatEnabled ? "ON" : "OFF")")

        // if isRepeatEnabled && !isPlaying && hasPlayableFiles {
        //     currentOfflineIndex = 0
        //     playOfflineCurrentFile()
        // }
    }
    
    func toggleShuffleMode() {
        objectWillChange.send()
        isShuffleEnabled.toggle()
        if isShuffleEnabled {
            shuffleHistory.removeAll()
            print("🧹 Shuffle履歴をリセット")
        }
        print("🔄 Shuffle mode: \(isShuffleEnabled ? "ON" : "OFF")")
    }
    
    func selectAndPlayOfflineFolder() {
        let supportedTypes: [UTType] = [
            UTType.mp3,
            UTType.wav,
            UTType.aiff,
            UTType(filenameExtension: "m4a")!,
            UTType(filenameExtension: "aac")!,
            UTType(filenameExtension: "caf")!
        ]
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: supportedTypes, asCopy: false)
        picker.delegate = self
        picker.allowsMultipleSelection = true
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootVC = window.rootViewController {
            rootVC.present(picker, animated: true)
        } else {
            print("🚫 UIが見つかりません")
        }
    }
    
    func playOfflineCurrentFile() {
        guard offlinePlaylist.indices.contains(currentOfflineIndex) else {
            print("🚫 プレイリストが空または範囲外")
            return
        }
        let url = offlinePlaylist[currentOfflineIndex]
        do {
            try configurePlaybackSession()
            player = try withCoordinatedReadAccess(to: url) { coordinatedURL in
                try AVAudioPlayer(contentsOf: coordinatedURL)
            }
            player?.delegate = self
            player?.volume = volume
            player?.numberOfLoops = 0
            guard player?.prepareToPlay() == true else {
                throw MusicManagerError.playerPreparationFailed(url)
            }
            guard player?.play() == true else {
                throw MusicManagerError.playerStartFailed(url)
            }
            isPlaying = true
            print("🎵 再生中: \(url.lastPathComponent)")
        } catch {
            isPlaying = false
            print("🚫 再生エラー: \(error.localizedDescription)")
        }
    }
    
    func playNextTrack() {
        guard hasPlayableFiles else { return }

        if isShuffleEnabled {
            // ✅ RepeatがOFFかつ全曲再生済みなら停止
            if !isRepeatEnabled && shuffleHistory.count >= offlinePlaylist.count {
                isPlaying = false
                print("🛑 Shuffle完了。Repeat OFFのため停止。")
                NotificationCenter.default.post(name: Notification.Name("NextButtonFlashRed"), object: nil)
                return
            }

            if isRepeatEnabled && shuffleHistory.count >= offlinePlaylist.count {
                print("🔁 Shuffle履歴をリセット（Repeat ON）")
                shuffleHistory.removeAll()
            }

            if offlinePlaylist.count > 1 {
                shuffleHistory.append(currentOfflineIndex)
                let availableIndices = (0..<offlinePlaylist.count).filter { $0 != currentOfflineIndex && !shuffleHistory.contains($0) }
                if let nextIndex = availableIndices.randomElement() {
                    currentOfflineIndex = nextIndex
                    playOfflineCurrentFile()
                } else {
                    print("ℹ️ 利用可能なトラックが見つかりません（すべて再生済み）")
                    isPlaying = false
                }
            } else {
                playOfflineCurrentFile()
            }
            return
        }

        if let range = repeatRange {
            if currentOfflineIndex < range.upperBound {
                currentOfflineIndex += 1
                playOfflineCurrentFile()
            } else {
                currentOfflineIndex = range.lowerBound
                playOfflineCurrentFile()
            }
        } else if currentOfflineIndex + 1 < offlinePlaylist.count {
            currentOfflineIndex += 1
            playOfflineCurrentFile()
        } else {
            if isRepeatEnabled {
                currentOfflineIndex = 0
                playOfflineCurrentFile()
            } else {
                isPlaying = false
                print("🛑 最後の曲。リピートOFFのため停止します。")
                NotificationCenter.default.post(name: Notification.Name("NextButtonFlashRed"), object: nil)
            }
        }
    }
    
    func playPreviousTrack() {
        guard hasPlayableFiles else { return }

        if isShuffleEnabled {
            if let previousIndex = shuffleHistory.popLast() {
                currentOfflineIndex = previousIndex
                playOfflineCurrentFile()
            } else {
                if isRepeatEnabled {
                    print("🔁 Shuffle履歴が空のため、最初の曲へ戻る")
                    currentOfflineIndex = 0
                    playOfflineCurrentFile()
                } else {
                    print("🛑 Shuffle履歴が空。戻れる曲がありません。")
                    isPlaying = false
                    NotificationCenter.default.post(name: Notification.Name("PrevButtonFlashRed"), object: nil)
                }
            }
        } else {
            if currentOfflineIndex > 0 {
                currentOfflineIndex -= 1
            } else if isRepeatEnabled {
                currentOfflineIndex = offlinePlaylist.count - 1
                playOfflineCurrentFile()
                return
            } else {
                print("🛑 最初の曲です。リピートOFFのため停止します。")
                isPlaying = false
                NotificationCenter.default.post(name: Notification.Name("PrevButtonFlashRed"), object: nil)
                return
            }
            playOfflineCurrentFile()
        }
    }
    
    func promptMusicSourceSelection() {
        DispatchQueue.main.async {
            let alert = UIAlertController(
                title: "音楽ソースを選択",
                message: "対応形式：MP3, WAV, M4A, AIFF, AAC, CAF",
                preferredStyle: .actionSheet
            )

            alert.addAction(UIAlertAction(title: "ローカルファイル", style: .default) { _ in
                self.currentMode = .offline
                self.selectAndPlayOfflineFolder()
            })

            alert.addAction(UIAlertAction(title: "キャンセル", style: .cancel, handler: nil))

            if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = scene.windows.first,
               let rootVC = window.rootViewController {
                if let popover = alert.popoverPresentationController {
                    popover.sourceView = rootVC.view
                    popover.sourceRect = CGRect(x: rootVC.view.bounds.midX, y: rootVC.view.bounds.maxY - 100, width: 0, height: 0)
                    popover.permittedArrowDirections = []
                }
                rootVC.present(alert, animated: true)
            } else {
                print("🚫 UIAlertController 表示に失敗（rootVCが見つかりません）")
            }
        }
    }
}

// =======================================================
// MARK: - UIDocumentPickerDelegate
// =======================================================
extension MusicManager {
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        print("📁 選択されたファイル: \(urls.map { $0.lastPathComponent })")
        let supportedExtensions = ["mp3", "wav", "m4a", "aiff", "aac", "caf"]
        let filtered = urls.filter { supportedExtensions.contains($0.pathExtension.lowercased()) }
        releaseSecurityScopedResources()

        var accessibleURLs: [URL] = []
        for url in filtered {
            guard url.startAccessingSecurityScopedResource() else {
                print("🚫 security-scoped resource 開始失敗: \(url.lastPathComponent)")
                continue
            }
            securityScopedURLs.append(url)
            accessibleURLs.append(url)
        }

        offlinePlaylist = accessibleURLs
        isFileSelected = !offlinePlaylist.isEmpty
        currentOfflineIndex = 0
        selectedFolderURL = offlinePlaylist.first?.deletingLastPathComponent()

        if !offlinePlaylist.isEmpty {
            print("✅ 再生可能ファイル数: \(offlinePlaylist.count)")
        } else {
            print("⚠️ 有効な音声ファイルが選ばれていません")
        }
    }
}

// =======================================================
// MARK: - AVAudioPlayerDelegate
// =======================================================
extension MusicManager {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        print("🎵 曲の再生が終了")
        playNextTrack()
    }
}

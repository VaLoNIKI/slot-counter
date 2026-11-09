import AVFoundation
import Foundation
import MediaPlayer
import Observation
import UIKit

// ロック画面の「再生中」コントロールでカウントする仕組み（アプリ本体のみ）。
//
// 無音の音声をループ再生して「音楽を再生中のアプリ」になり、ロック画面の
// 前の曲／再生・一時停止／次の曲ボタン（MPRemoteCommandCenter）を受け取る。
// これらのボタンは音楽アプリと同じ扱いなので、ロック中でも Face ID なしで押せる。
// アプリは裏で動き続けるので、カウントの保存とライブアクティビティの更新もその場で行える。
//
// - 次の曲 = 機種ごとに選んだ項目を +1（初期値：ジャグラーはブドウ、ハナハナはベル、汎用はベル）
// - 前の曲 = 機種ごとに選んだ項目を +1（初期値：ジャグラーはチェリー、ハナハナはスイカ、汎用はチェリー）
// - 再生/一時停止 = 直前を取消（設定で「何もしない」にもできる）
// 曲名・アーティスト名の欄に回数と確率を表示する。
// Info.plist の UIBackgroundModes に audio が必要。
//
// 実験的：音量ボタンでも数える（音量＋ = 次の曲の割り当て、音量− = 前の曲の割り当て）。
// 音を流している間は AVAudioSession.outputVolume の変化を受け取れる（Apple のフォーラムでの回答）。
// 背面タップに「音量を上げる／下げる」を割り当てれば、背面タップでも数えられる。
// 数えるたびに、画面に置いた MPVolumeView で音量をユーザーの元の音量に戻す。
// ただし元の音量が最大（最小）だと「上げる（下げる）」で変化が起きず数えられないので、そのときは1目盛り内側を基準にする。
// 機能をオフにしたとき・止めたときは、オンにする前の音量にそのまま戻す。

@MainActor
@Observable
final class NowPlayingCounter {
    static let shared = NowPlayingCounter()

    private static let enabledKey = "nowPlayingCounter.enabled"
    private static let playPauseUndoKey = "nowPlayingCounter.playPauseUndo"
    private static let volumeButtonsKey = "nowPlayingCounter.volumeButtons"

    private enum RemoteAction {
        case next
        case previous
        case playPause
    }

    private(set) var isRunning = false
    var errorMessage: String?

    /// 再生/一時停止ボタンで直前を取り消すか（false なら何もしない）
    var playPauseUndoes: Bool = UserDefaults.standard.object(forKey: playPauseUndoKey) as? Bool ?? true {
        didSet {
            UserDefaults.standard.set(playPauseUndoes, forKey: Self.playPauseUndoKey)
            updateNowPlayingInfo()
        }
    }

    /// 音量ボタン（背面タップの「音量を上げる／下げる」を含む）でも数えるか（実験的）
    var volumeButtonsEnabled: Bool = UserDefaults.standard.bool(forKey: volumeButtonsKey) {
        didSet {
            UserDefaults.standard.set(volumeButtonsEnabled, forKey: Self.volumeButtonsKey)
            updateVolumeObservation()
        }
    }

    @ObservationIgnored private var volumeObservation: NSKeyValueObservation?
    /// 自分で音量を戻したときの変化を数えないための期限
    @ObservationIgnored private var ignoreVolumeUntil = Date.distantPast
    /// 機能をオンにしたときのユーザーの音量（オフにしたら戻す）
    @ObservationIgnored private var userVolume: Float?
    /// 数えたあとに戻す音量（ユーザーの音量。端なら1目盛り内側）
    @ObservationIgnored private var baseVolume: Float = 0.5
    /// iPhone の音量の1目盛り（16段階）
    private static let volumeStep: Float = 1.0 / 16.0
    /// 音量を戻すための MPVolumeView（実戦画面に見えない大きさで置く）
    @ObservationIgnored private weak var volumeView: MPVolumeView?

    @ObservationIgnored private var player: AVAudioPlayer?
    @ObservationIgnored private var commandTargets: [(MPRemoteCommand, Any)] = []
    @ObservationIgnored private var interruptionObserver: NSObjectProtocol?
    /// 1回のタップで再生/一時停止系のコマンドが重なって届いても、取消を1回にする
    @ObservationIgnored private var lastPlayPauseAt = Date.distantPast

    private init() {}

    /// 前回オンのままアプリが終了していたら、起動時に再開する
    func restoreIfNeeded() {
        if UserDefaults.standard.bool(forKey: Self.enabledKey), !isRunning {
            start()
        }
    }

    func start() {
        do {
            let session = AVAudioSession.sharedInstance()
            // 他のアプリと混ぜない（混ぜると「再生中」の主役にならず、ロック画面にボタンが出ない）
            try session.setCategory(.playback, mode: .default, options: [])
            try session.setActive(true)
            if player == nil {
                let silent = try AVAudioPlayer(data: Self.silentWAV())
                silent.numberOfLoops = -1
                silent.prepareToPlay()
                player = silent
            }
            player?.play()
            registerCommands()
            observeInterruptions()
            CounterModel.shared.onChange = { [weak self] in
                self?.updateNowPlayingInfo()
            }
            isRunning = true
            errorMessage = nil
            UserDefaults.standard.set(true, forKey: Self.enabledKey)
            updateNowPlayingInfo()
            updateVolumeObservation()
        } catch {
            errorMessage = "開始できませんでした: \(error.localizedDescription)"
            isRunning = false
        }
    }

    func stop() {
        volumeObservation?.invalidate()
        volumeObservation = nil
        restoreUserVolume()
        player?.stop()
        unregisterCommands()
        if let interruptionObserver {
            NotificationCenter.default.removeObserver(interruptionObserver)
        }
        interruptionObserver = nil
        CounterModel.shared.onChange = nil
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
        MPNowPlayingInfoCenter.default().playbackState = .stopped
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        isRunning = false
        UserDefaults.standard.set(false, forKey: Self.enabledKey)
    }

    // MARK: - Remote commands

    private func registerCommands() {
        unregisterCommands()
        let center = MPRemoteCommandCenter.shared()

        // 次の曲／前の曲ボタンを出すため、スキップやシーク系は無効にする
        let unused: [MPRemoteCommand] = [
            center.skipForwardCommand,
            center.skipBackwardCommand,
            center.seekForwardCommand,
            center.seekBackwardCommand,
            center.changePlaybackPositionCommand,
            center.changePlaybackRateCommand,
            center.changeRepeatModeCommand,
            center.changeShuffleModeCommand,
            center.likeCommand,
            center.dislikeCommand,
            center.bookmarkCommand,
        ]
        for command in unused {
            command.isEnabled = false
        }

        add(center.nextTrackCommand, .next)
        add(center.previousTrackCommand, .previous)
        add(center.togglePlayPauseCommand, .playPause)
        add(center.pauseCommand, .playPause)
        add(center.playCommand, .playPause)
    }

    private func add(_ command: MPRemoteCommand, _ action: RemoteAction) {
        command.isEnabled = true
        let token = command.addTarget { [weak self] _ in
            MainActor.assumeIsolated {
                self?.handle(action)
            }
            return .success
        }
        commandTargets.append((command, token))
    }

    private func unregisterCommands() {
        for (command, token) in commandTargets {
            command.removeTarget(token)
        }
        commandTargets.removeAll()
    }

    private func handle(_ action: RemoteAction) {
        let model = CounterModel.shared
        switch action {
        case .next:
            model.increment(model.nextTrackRole)
        case .previous:
            model.increment(model.previousTrackRole)
        case .playPause:
            let now = Date()
            guard playPauseUndoes, now.timeIntervalSince(lastPlayPauseAt) > 0.4 else {
                keepPlaying()
                return
            }
            lastPlayPauseAt = now
            model.undo()
        }
        keepPlaying()
        Task { await model.syncLiveActivities() }
    }

    /// 一時停止ボタンを押されても再生を続け、表示を「再生中」のままにする
    private func keepPlaying() {
        if player?.isPlaying == false {
            player?.play()
        }
        updateNowPlayingInfo()
    }

    // MARK: - Now Playing 表示

    func updateNowPlayingInfo() {
        guard isRunning else { return }
        let model = CounterModel.shared
        let games = model.totalGames

        func summary(_ role: Role) -> String {
            let count = model.count(role)
            return "\(role.label) \(count) (\(Probability.text(games: games, count: count)))"
        }

        let title = "⏭\(summary(model.nextTrackRole))  ⏮\(summary(model.previousTrackRole))"

        var detail: [String] = []
        if let last = model.current.lastAction {
            detail.append("直前: \(last)")
        }
        detail.append(model.selectedMachine.label)
        if games > 0 {
            detail.append("\(games)G")
        }
        if let bonus = model.bonusTotal {
            detail.append("合算 \(Probability.text(games: games, count: bonus))")
        }

        let all = model.selectedMachine.roles
            .map { "\($0.label)\(model.count($0))" }
            .joined(separator: " ")
        let album = "\(all)  ⏯=\(playPauseUndoes ? "取消" : "なし")"

        MPNowPlayingInfoCenter.default().nowPlayingInfo = [
            MPMediaItemPropertyTitle: title,
            MPMediaItemPropertyArtist: detail.joined(separator: " ・ "),
            MPMediaItemPropertyAlbumTitle: album,
            MPNowPlayingInfoPropertyMediaType: MPNowPlayingInfoMediaType.audio.rawValue,
            MPNowPlayingInfoPropertyPlaybackRate: 1.0,
        ]
        MPNowPlayingInfoCenter.default().playbackState = .playing
    }

    // MARK: - 中断（電話など）からの復帰

    private func observeInterruptions() {
        if let interruptionObserver {
            NotificationCenter.default.removeObserver(interruptionObserver)
        }
        interruptionObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance(),
            queue: .main
        ) { [weak self] notification in
            guard
                let raw = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
                AVAudioSession.InterruptionType(rawValue: raw) == .ended
            else { return }
            MainActor.assumeIsolated {
                self?.resumeAfterInterruption()
            }
        }
    }

    private func resumeAfterInterruption() {
        guard isRunning else { return }
        try? AVAudioSession.sharedInstance().setActive(true)
        player?.play()
        registerCommands()
        updateNowPlayingInfo()
        updateVolumeObservation()
    }

    // MARK: - 音量ボタン（実験的）

    func attach(volumeView: MPVolumeView) {
        self.volumeView = volumeView
    }

    private func updateVolumeObservation() {
        volumeObservation?.invalidate()
        volumeObservation = nil
        guard isRunning, volumeButtonsEnabled else {
            restoreUserVolume()
            return
        }
        let current = AVAudioSession.sharedInstance().outputVolume
        if userVolume == nil {
            userVolume = current
        }
        baseVolume = min(max(current, Self.volumeStep), 1 - Self.volumeStep)
        if abs(baseVolume - current) > 0.001 {
            setVolume(baseVolume)
        }
        volumeObservation = AVAudioSession.sharedInstance().observe(\.outputVolume, options: [.old, .new]) { [weak self] _, change in
            guard let old = change.oldValue, let new = change.newValue else { return }
            Task { @MainActor in
                self?.handleVolumeChange(old: old, new: new)
            }
        }
    }

    private func handleVolumeChange(old: Float, new: Float) {
        guard isRunning, volumeButtonsEnabled, Date() >= ignoreVolumeUntil else { return }
        if new > old {
            handle(.next)
        } else if new < old {
            handle(.previous)
        } else {
            return
        }
        setVolume(baseVolume)
    }

    /// オンにする前の音量に戻す（オフにしたとき・止めたとき）
    private func restoreUserVolume() {
        guard let userVolume else { return }
        self.userVolume = nil
        setVolume(userVolume)
    }

    /// 音量を変える。自分で変えた分は数えないよう、少しの間は変化を無視する
    private func setVolume(_ volume: Float) {
        guard let slider = volumeView?.subviews.compactMap({ $0 as? UISlider }).first else { return }
        ignoreVolumeUntil = Date().addingTimeInterval(0.25)
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(10))
            slider.value = volume
        }
    }

    // MARK: - 無音データ

    /// 1秒の 16bit モノラル WAV。完全な無音だと再生扱いにならない可能性があるので、
    /// 聞こえない最小振幅（±1 / 32768）を入れる。
    private static func silentWAV(sampleRate: Int = 44_100) -> Data {
        let frameCount = sampleRate
        var pcm = Data(capacity: frameCount * 2)
        for index in 0..<frameCount {
            let sample: Int16 = index.isMultiple(of: 2) ? 1 : -1
            pcm.append(littleEndian: UInt16(bitPattern: sample))
        }

        var wav = Data()
        wav.append(contentsOf: Array("RIFF".utf8))
        wav.append(littleEndian: UInt32(36 + pcm.count))
        wav.append(contentsOf: Array("WAVE".utf8))
        wav.append(contentsOf: Array("fmt ".utf8))
        wav.append(littleEndian: UInt32(16))
        wav.append(littleEndian: UInt16(1)) // PCM
        wav.append(littleEndian: UInt16(1)) // モノラル
        wav.append(littleEndian: UInt32(sampleRate))
        wav.append(littleEndian: UInt32(sampleRate * 2)) // byte rate
        wav.append(littleEndian: UInt16(2)) // block align
        wav.append(littleEndian: UInt16(16)) // bits per sample
        wav.append(contentsOf: Array("data".utf8))
        wav.append(littleEndian: UInt32(pcm.count))
        wav.append(pcm)
        return wav
    }
}

private extension Data {
    mutating func append(littleEndian value: UInt16) {
        Swift.withUnsafeBytes(of: value.littleEndian) { append(contentsOf: $0) }
    }

    mutating func append(littleEndian value: UInt32) {
        Swift.withUnsafeBytes(of: value.littleEndian) { append(contentsOf: $0) }
    }
}

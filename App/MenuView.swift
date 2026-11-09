import SwiftUI

/// 実戦画面の「メニュー」。実戦中にあまり触らない設定と操作をまとめる
struct MenuView: View {
    let activity: LiveActivityController

    @Environment(\.dismiss) private var dismiss
    @State private var model = CounterModel.shared
    @State private var nowPlaying = NowPlayingCounter.shared
    @State private var archive = SessionArchive.shared
    @State private var showResetConfirm = false
    @State private var showSaveSession = false

    private var stats: PlayStats {
        PlayStats(machine: model.selectedMachine, data: model.current)
    }

    var body: some View {
        NavigationStack {
            Form {
                playSection
                machineSection
                nowPlayingSection
                liveActivitySection
            }
            .navigationTitle("メニュー")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
            .confirmationDialog(
                "\(model.selectedMachine.label)のカウント・総回転数・ボーナス履歴をリセットしますか？",
                isPresented: $showResetConfirm,
                titleVisibility: .visible
            ) {
                Button("リセット", role: .destructive) {
                    model.resetCurrentMachine()
                    sync()
                }
            }
            .sheet(isPresented: $showSaveSession) {
                SessionSaveSheet(stats: stats, initialStoreName: archive.lastStoreName) { storeName, number in
                    archive.add(SessionRecord(
                        savedAt: Date(),
                        storeName: storeName,
                        machineNumber: number,
                        machine: model.selectedMachine,
                        data: model.current
                    ))
                    model.resetCurrentMachine()
                    sync()
                    dismiss()
                }
            }
        }
    }

    // MARK: - 実戦

    private var playSection: some View {
        Section("実戦") {
            if model.selectedMachine.hasBonus {
                NavigationLink {
                    BonusHistoryView()
                } label: {
                    LabeledContent("ボーナス履歴", value: "\(model.bonuses.count)件")
                }
            }
            if FeatureAccess.isUnlocked(.sessionHistory) {
                Button {
                    showSaveSession = true
                } label: {
                    Label("実戦を保存して新しく始める", systemImage: "square.and.arrow.down")
                }
            }
            Button(role: .destructive) {
                showResetConfirm = true
            } label: {
                Label("この機種をリセット（保存しない）", systemImage: "trash")
            }
        }
    }

    // MARK: - 機種

    private var machineSection: some View {
        Section {
            Picker("機種", selection: Binding(
                get: { model.selectedMachine },
                set: { machine in
                    model.selectMachine(machine)
                    sync()
                }
            )) {
                ForEach(Machine.allCases) { machine in
                    Text(machine.label).tag(machine)
                }
            }
            .pickerStyle(.segmented)
            if model.selectedMachine == .juggler {
                Picker("台", selection: Binding(
                    get: { model.jugglerModel },
                    set: { jugglerModel in
                        model.setJugglerModel(jugglerModel)
                        sync()
                    }
                )) {
                    ForEach(JugglerModel.allCases) { jugglerModel in
                        Text(jugglerModel.label).tag(jugglerModel)
                    }
                }
                if FeatureAccess.isUnlocked(.specComparison) {
                    NavigationLink("スペック表") {
                        SpecTableView(model: model.jugglerModel, stats: stats)
                    }
                }
                NavigationLink("詳しい集計") {
                    StatsDetailView()
                }
            }
        } header: {
            Text("機種")
        } footer: {
            Text("カウントと総回転数は機種（汎用／ジャグラー／ハナハナ）ごとに保存されます。切り替えても消えません。")
        }
    }

    // MARK: - ロック画面の再生ボタン

    private var nowPlayingSection: some View {
        Section {
            Toggle("再生ボタンで数える", isOn: Binding(
                get: { nowPlaying.isRunning },
                set: { on in
                    if on {
                        nowPlaying.start()
                    } else {
                        nowPlaying.stop()
                    }
                }
            ))
            Picker("⏭ 次の曲", selection: Binding(
                get: { model.nextTrackRole },
                set: { role in
                    model.setNextTrackRole(role)
                    sync()
                }
            )) {
                ForEach(model.selectedMachine.roles) { role in
                    Text("\(role.label) +1").tag(role)
                }
            }
            Picker("⏮ 前の曲", selection: Binding(
                get: { model.previousTrackRole },
                set: { role in
                    model.setPreviousTrackRole(role)
                    sync()
                }
            )) {
                ForEach(model.selectedMachine.roles) { role in
                    Text("\(role.label) +1").tag(role)
                }
            }
            Picker("⏯ 再生/一時停止", selection: $nowPlaying.playPauseUndoes) {
                Text("直前を取消").tag(true)
                Text("何もしない").tag(false)
            }
            Toggle("音量ボタン・背面タップでも数える（実験的）", isOn: $nowPlaying.volumeButtonsEnabled)
            if let message = nowPlaying.errorMessage {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
        } header: {
            Text("ロック画面の再生ボタンでカウント")
        } footer: {
            Text("オンにすると無音の音声を流し、ロック画面の「再生中」の枠（音楽アプリと同じ場所）の ⏮ ⏯ ⏭ ボタンでカウントできます。ロック中でも Face ID なしで押せます。使っている間は他の音楽アプリと同時に使えません。割り当ては機種ごとに保存されます。

音量ボタン（実験的）：音量＋で ⏭ の割り当て、音量−で ⏮ の割り当てを +1 します。設定 > アクセシビリティ > タッチ > 背面タップ で「ダブルタップ＝音量を上げる」「トリプルタップ＝音量を下げる」にすると、背面タップで数えられます。数えるたびに音量は中間に戻ります。")
        }
    }

    // MARK: - ライブアクティビティ

    private var liveActivitySection: some View {
        Section {
            HStack {
                Circle()
                    .fill(activity.isRunning ? Color.green : Color.gray)
                    .frame(width: 10, height: 10)
                Text(activity.isRunning ? "ロック画面に表示中" : "停止中")
                Spacer()
            }
            HStack(spacing: 12) {
                Button {
                    Task { await activity.start(with: model) }
                } label: {
                    Text(activity.isRunning ? "再開始" : "開始")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)

                Button(role: .destructive) {
                    Task { await activity.stop() }
                } label: {
                    Text("停止")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(!activity.isRunning)
            }
            if let message = activity.errorMessage {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
        } header: {
            Text("ライブアクティビティ")
        } footer: {
            Text("ロック画面に回数・確率・ハマりを表示します。表示は最長8時間で終了しますが、カウントは保存されているので「再開始」で続きから表示できます。")
        }
    }

    private func sync() {
        Task { await model.syncLiveActivities() }
    }
}

/// ボーナス履歴（新しい順）。タップで重複・総回転数を直す、左スワイプで削除
struct BonusHistoryView: View {
    @State private var model = CounterModel.shared
    @State private var editing: BonusRecord?

    var body: some View {
        let bonuses = model.bonuses
        let between = PlayStats(machine: model.selectedMachine, data: model.current).gamesBetweenBonuses
        List {
            if bonuses.isEmpty {
                Text("まだボーナスの記録はありません。")
                    .foregroundStyle(.secondary)
            }
            ForEach(Array(bonuses.enumerated().reversed()), id: \.element.id) { index, record in
                Button {
                    editing = record
                } label: {
                    BonusHistoryRow(number: index + 1, record: record, gamesBetween: between[record.id])
                        .foregroundStyle(.primary)
                }
                .swipeActions {
                    Button("削除", role: .destructive) {
                        model.deleteBonus(record.id)
                        sync()
                    }
                }
            }
        }
        .navigationTitle("ボーナス履歴")
        .sheet(item: $editing) { record in
            BonusEditSheet(
                record: record,
                showsOverlap: model.selectedMachine == .juggler,
                onSave: { overlap, total in
                    model.updateBonus(record.id, overlap: overlap, totalGames: total)
                    sync()
                },
                onDelete: {
                    model.deleteBonus(record.id)
                    sync()
                }
            )
        }
    }

    private func sync() {
        Task { await model.syncLiveActivities() }
    }
}

/// 今の実戦の詳しい集計（小役・ボーナスの内訳・設定推測の6本の棒）
struct StatsDetailView: View {
    @State private var model = CounterModel.shared

    var body: some View {
        let stats = PlayStats(machine: model.selectedMachine, data: model.current)
        Form {
            Section("小役") {
                ForEach(model.selectedMachine.roles.filter { $0 != .big && $0 != .reg }) { role in
                    StatRow(label: role.label, color: role.color, count: stats.count(role),
                            probability: stats.probability(stats.count(role)),
                            nearest: stats.nearest(for: role))
                }
            }
            if model.selectedMachine.hasBonus {
                Section("ボーナス") {
                    BonusSummaryRows(stats: stats)
                }
            }
            if let estimate = stats.settingEstimate {
                Section {
                    SettingEstimateRows(estimate: estimate)
                } header: {
                    Text("設定推測（暫定）")
                } footer: {
                    Text("スペック表の \(estimate.usedMetrics.joined(separator: "・")) の確率から計算した目安です（どの設定も最初は同じ確率として計算）。G数が少ないうちはあてになりません。ぶどうは1回以上数えているときだけ使います。")
                }
            }
        }
        .navigationTitle("詳しい集計")
        .navigationBarTitleDisplayMode(.inline)
    }
}

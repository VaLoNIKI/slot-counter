import SwiftUI

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var model = CounterModel.shared
    @State private var activity = LiveActivityController()
    @State private var nowPlaying = NowPlayingCounter.shared
    @State private var gamesText = ""
    @State private var showResetConfirm = false
    @FocusState private var gamesFocused: Bool

    var body: some View {
        NavigationStack {
            Form {
                machineSection
                nowPlayingSection
                liveActivitySection
                gamesSection
                countsSection
                actionsSection
            }
            .navigationTitle("小役カウンター")
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("完了") { gamesFocused = false }
                }
            }
            .confirmationDialog(
                "\(model.selectedMachine.label)のカウントと総G数をリセットしますか？",
                isPresented: $showResetConfirm,
                titleVisibility: .visible
            ) {
                Button("リセット", role: .destructive) {
                    model.resetCurrentMachine()
                    refreshGamesText()
                    sync()
                }
            }
        }
        .onAppear {
            refreshGamesText()
            activity.refresh()
            nowPlaying.restoreIfNeeded()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                model.reloadFromDisk()
                if !gamesFocused { refreshGamesText() }
                activity.refresh()
            }
        }
    }

    // MARK: - Sections

    private var machineSection: some View {
        Section {
            Picker("機種", selection: Binding(
                get: { model.selectedMachine },
                set: { machine in
                    gamesFocused = false
                    model.selectMachine(machine)
                    refreshGamesText()
                    sync()
                }
            )) {
                ForEach(Machine.allCases) { machine in
                    Text(machine.label).tag(machine)
                }
            }
            .pickerStyle(.segmented)
        } header: {
            Text("機種")
        } footer: {
            Text("カウントと総G数は機種ごとに保存されます。切り替えても消えません。")
        }
    }

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
            if let message = nowPlaying.errorMessage {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
        } header: {
            Text("ロック画面の再生ボタンでカウント")
        } footer: {
            Text("オンにすると無音の音声を流し、ロック画面の「再生中」の枠（音楽アプリと同じ場所）の ⏮ ⏯ ⏭ ボタンでカウントできます。ロック中でも Face ID なしで押せます。曲名の欄に回数と確率が出ます。使っている間は他の音楽アプリと同時に使えません。割り当ては機種ごとに保存されます。")
        }
    }

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
            Text("ロック画面のタイルを押すと+1できます（ロック中は Face ID などで解除後に実行）。ロックしたまま入力するときはコントロール（コントロールセンター／ロック画面の左右ボタン／アクションボタン）を使います。表示は最長8時間で終了しますが、カウントは保存されているので「再開始」で続きから表示できます。")
        }
    }

    private var gamesSection: some View {
        Section("総G数") {
            HStack {
                TextField("例: 3000", text: $gamesText)
                    .keyboardType(.numberPad)
                    .focused($gamesFocused)
                    .font(.title3.monospacedDigit())
                Text("G")
                    .foregroundStyle(.secondary)
            }
            .onChange(of: gamesText) { _, newValue in
                let digits = newValue.filter(\.isNumber)
                if digits != newValue {
                    gamesText = digits
                    return
                }
                let games = Int(digits) ?? 0
                if games != model.totalGames {
                    model.setTotalGames(games)
                    sync()
                }
            }
        }
    }

    private var countsSection: some View {
        Section("\(model.selectedMachine.label)（タップで+1）") {
            ForEach(model.selectedMachine.roles) { role in
                Button {
                    model.increment(role)
                    sync()
                } label: {
                    HStack {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(role.color)
                            .frame(width: 6, height: 28)
                        Text(role.label)
                            .foregroundStyle(.primary)
                        Spacer()
                        Text("\(model.count(role))回")
                            .font(.title3.bold().monospacedDigit())
                            .foregroundStyle(.primary)
                        probabilityText(count: model.count(role))
                    }
                }
            }
            if let bonus = model.bonusTotal {
                HStack {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(LinearGradient(colors: [Role.big.color, Role.reg.color], startPoint: .top, endPoint: .bottom))
                        .frame(width: 6, height: 28)
                    Text("ボーナス合算")
                    Spacer()
                    Text("\(bonus)回")
                        .font(.title3.bold().monospacedDigit())
                    probabilityText(count: bonus)
                }
            }
        }
    }

    private var actionsSection: some View {
        Section {
            Button {
                model.undo()
                sync()
            } label: {
                Label("直前を取り消す", systemImage: "arrow.uturn.backward")
            }
            .disabled(!model.canUndo)

            Button(role: .destructive) {
                showResetConfirm = true
            } label: {
                Label("この機種をリセット", systemImage: "trash")
            }
        } footer: {
            if let last = model.current.lastAction {
                Text("直前: \(last)")
            }
        }
    }

    // MARK: - Helpers

    private func probabilityText(count: Int) -> some View {
        Text(Probability.text(games: model.totalGames, count: count))
            .font(.body.monospacedDigit())
            .foregroundStyle(.secondary)
            .frame(minWidth: 72, alignment: .trailing)
    }

    private func refreshGamesText() {
        gamesText = model.totalGames > 0 ? String(model.totalGames) : ""
    }

    private func sync() {
        Task { await model.syncLiveActivities() }
    }
}

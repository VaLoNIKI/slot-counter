import SwiftUI

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var model = CounterModel.shared
    @State private var activity = LiveActivityController()
    @State private var nowPlaying = NowPlayingCounter.shared
    @State private var archive = SessionArchive.shared
    @State private var startText = ""
    @State private var currentText = ""
    @State private var showResetConfirm = false
    @State private var showSaveSession = false
    @State private var bonusEntry: BonusEntry?
    @State private var editingBonus: BonusRecord?
    @FocusState private var focusedField: TotalField?

    private enum TotalField {
        case start
        case current
    }

    private var stats: PlayStats {
        PlayStats(machine: model.selectedMachine, data: model.current)
    }

    var body: some View {
        NavigationStack {
            Form {
                machineSection
                gamesSection
                countsSection
                if model.selectedMachine.hasBonus {
                    bonusSection
                    bonusHistorySection
                }
                actionsSection
                nowPlayingSection
                liveActivitySection
            }
            .navigationTitle("小役カウンター")
            .toolbar {
                if FeatureAccess.isUnlocked(.sessionHistory) {
                    ToolbarItem(placement: .topBarTrailing) {
                        NavigationLink {
                            SessionListView()
                        } label: {
                            Label("履歴", systemImage: "clock.arrow.circlepath")
                        }
                    }
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("完了") { focusedField = nil }
                }
            }
            .confirmationDialog(
                "\(model.selectedMachine.label)のカウント・総回転数・ボーナス履歴をリセットしますか？",
                isPresented: $showResetConfirm,
                titleVisibility: .visible
            ) {
                Button("リセット", role: .destructive) {
                    model.resetCurrentMachine()
                    refreshTotalTexts()
                    sync()
                }
            }
            .sheet(item: $bonusEntry) { entry in
                BonusEntrySheet(entry: entry, initialTotal: model.current.currentTotal) { total in
                    model.recordBonus(entry.kind, overlap: entry.overlap, totalGames: total)
                    refreshTotalTexts()
                    sync()
                }
            }
            .sheet(item: $editingBonus) { record in
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
                    refreshTotalTexts()
                    sync()
                }
            }
        }
        .onAppear {
            refreshTotalTexts()
            activity.refresh()
            nowPlaying.restoreIfNeeded()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                model.reloadFromDisk()
                if focusedField == nil { refreshTotalTexts() }
                activity.refresh()
            }
        }
    }

    // MARK: - 機種

    private var machineSection: some View {
        Section {
            Picker("機種", selection: Binding(
                get: { model.selectedMachine },
                set: { machine in
                    focusedField = nil
                    model.selectMachine(machine)
                    refreshTotalTexts()
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
            }
        } header: {
            Text("機種")
        } footer: {
            Text("カウントと総回転数は機種（汎用／ジャグラー／ハナハナ）ごとに保存されます。切り替えても消えません。")
        }
    }

    // MARK: - G数

    private var gamesSection: some View {
        Section {
            totalField("打ち始め", text: $startText, field: .start) { model.setStartTotal($0) }
            totalField("現在", text: $currentText, field: .current) { model.setCurrentTotal($0) }
            LabeledContent("自分のG数") {
                Text("\(model.totalGames)G")
                    .font(.title3.bold().monospacedDigit())
                    .foregroundStyle(.primary)
            }
            if let since = model.sinceLastBonus {
                LabeledContent("ハマり（最後のボーナスから）") {
                    Text("\(since)G")
                        .font(.body.bold().monospacedDigit())
                        .foregroundStyle(.primary)
                }
            }
        } header: {
            Text("総回転数（データカウンター）")
        } footer: {
            Text("台のデータカウンターの総回転数を入れます。自分のG数 = 現在 − 打ち始め。確率はすべて自分のG数で計算します。")
        }
    }

    private func totalField(
        _ title: String,
        text: Binding<String>,
        field: TotalField,
        onCommit: @escaping (Int?) -> Void
    ) -> some View {
        LabeledContent(title) {
            TextField("0", text: text)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.trailing)
                .focused($focusedField, equals: field)
                .font(.title3.monospacedDigit())
                .onChange(of: text.wrappedValue) { _, newValue in
                    let digits = newValue.filter(\.isNumber)
                    if digits != newValue {
                        text.wrappedValue = digits
                        return
                    }
                    onCommit(digits.isEmpty ? nil : Int(digits))
                    sync()
                }
        }
    }

    // MARK: - 小役

    private var smallRoles: [Role] {
        model.selectedMachine.roles.filter { !model.selectedMachine.hasBonus || ($0 != .big && $0 != .reg) }
    }

    private var countsSection: some View {
        Section("小役（タップで+1）") {
            ForEach(smallRoles) { role in
                Button {
                    model.increment(role)
                    sync()
                } label: {
                    StatRow(
                        label: role.label,
                        color: role.color,
                        count: model.count(role),
                        probability: stats.probability(model.count(role)),
                        nearest: role == .grape ? stats.nearest(.grape, count: model.count(role)) : nil
                    )
                    .foregroundStyle(.primary)
                }
            }
        }
    }

    // MARK: - ボーナス

    private var bonusSection: some View {
        Section {
            if model.selectedMachine == .juggler {
                Grid(horizontalSpacing: 8, verticalSpacing: 8) {
                    GridRow {
                        bonusButton(.big, .alone)
                        bonusButton(.big, .cherry)
                    }
                    GridRow {
                        bonusButton(.reg, .alone)
                        bonusButton(.reg, .cherry)
                    }
                }
                .padding(.vertical, 4)
            } else {
                HStack(spacing: 8) {
                    bonusButton(.big, nil)
                    bonusButton(.reg, nil)
                }
                .padding(.vertical, 4)
            }
            BonusSummaryRows(stats: stats)
        } header: {
            Text("ボーナス（ボタンで記録）")
        } footer: {
            if model.selectedMachine == .juggler {
                Text("「付近」はスペック表で一番近い設定です（設定推測ではありません）。G数が少ないうちは大きくぶれます。ロック画面やコントロールから記録したボーナスは重複「不明」になるので、下の履歴をタップして直せます。")
            }
        }
    }

    private func bonusButton(_ kind: Role, _ overlap: BonusOverlap?) -> some View {
        let entry = BonusEntry(kind: kind, overlap: overlap)
        return Button {
            focusedField = nil
            bonusEntry = entry
        } label: {
            Text(entry.title)
                .bold()
                .frame(maxWidth: .infinity, minHeight: 36)
        }
        .buttonStyle(.borderedProminent)
        .tint(kind.color)
    }

    @ViewBuilder
    private var bonusHistorySection: some View {
        let bonuses = model.bonuses
        if !bonuses.isEmpty {
            let between = stats.gamesBetweenBonuses
            Section("ボーナス履歴（新しい順・タップで編集）") {
                ForEach(Array(bonuses.enumerated().reversed()), id: \.element.id) { index, record in
                    Button {
                        editingBonus = record
                    } label: {
                        BonusHistoryRow(number: index + 1, record: record, gamesBetween: between[record.id])
                            .foregroundStyle(.primary)
                    }
                }
            }
        }
    }

    // MARK: - 操作

    private var actionsSection: some View {
        Section {
            Button {
                model.undo()
                sync()
            } label: {
                Label("直前を取り消す", systemImage: "arrow.uturn.backward")
            }
            .disabled(!model.canUndo)

            if FeatureAccess.isUnlocked(.sessionHistory) {
                Button {
                    focusedField = nil
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
        } footer: {
            if let last = model.current.lastAction {
                Text("直前: \(last)")
            }
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
            Text("ロック画面に回数・確率・ハマりを表示します。タイルを押すと+1できます（ロック中は Face ID が必要）。表示は最長8時間で終了しますが、カウントは保存されているので「再開始」で続きから表示できます。")
        }
    }

    // MARK: - Helpers

    private func refreshTotalTexts() {
        startText = model.current.startTotal.map(String.init) ?? ""
        currentText = model.current.currentTotal.map(String.init) ?? ""
    }

    private func sync() {
        Task { await model.syncLiveActivities() }
    }
}
